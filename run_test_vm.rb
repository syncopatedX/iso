#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'ostruct'
require 'shellwords'
require 'tty-prompt'

# @!parse ENV = Hash
# User's home directory.
HOME = ENV['HOME']
# The root directory of the application script.
APP_ROOT = __dir__

# --- Base Command Class ---

# Represents a command to be executed externally.
# Provides a structure for building and executing commands safely.
class Command
  # @return [OpenStruct] The configuration object for the command.
  attr_reader :config

  # Initializes a new Command instance.
  # Configuration is expected to be an object/struct responding to necessary methods
  def initialize(config)
    @config = config
  end

  # Subclasses must implement this to return an array of command parts
  def build_command_array
    # @abstract Subclass is expected to implement #build_command_array
    # @raise [NotImplementedError] If the subclass does not implement this method.
    # @return [Array<String>] An array of strings representing the command and its arguments.
    raise NotImplementedError, "#{self.class} has not implemented build_command_array"
  end

  def execute
    # Executes the command built by {#build_command_array}.
    cmd_array = build_command_array
    puts "Executing command: #{Shellwords.join(cmd_array)}"

    pid = fork do
      # exec replaces the current process; pass arguments separately for safety
      # No need to manually escape if passing as separate args to exec
      exec(*cmd_array)
      # exec only returns if it fails
      warn "ERROR: Failed to execute command: #{cmd_array.first}"
      exit!(1) # Exit child process immediately on exec failure
    end

    _pid, status = Process.wait2(pid)

    unless status.success?
      warn "ERROR: Command failed with exit status: #{status.exitstatus}"
      # Consider raising a custom error here for better control flow
      # raise CommandExecutionError, "Command failed: #{Shellwords.join(cmd_array)}"
      exit(status.exitstatus || 1) # Exit script if command failed
    end

    puts 'Command completed successfully.'
  end
end

# --- QEMU System Command ---

# Represents the `qemu-system-x86_64` command for running a VM.
class QemuSystem < Command
  # Builds the command array for `qemu-system-x86_64`.
  # Expects config fields: :selected_iso, :selected_drive, :vcpus, :memory
  # @return [Array<String>] The command array.
  def build_command_array
    [
      'qemu-system-x86_64',
      '-cdrom', config.selected_iso,
      '-cpu', 'host',
      '-enable-kvm',
      '-m', config.memory.to_s,
      '-smp', config.vcpus.to_s,
      # NOTE: -drive argument format requires careful construction
      '-drive', "file=#{config.selected_drive},format=qcow2",
      '-device', 'intel-hda'
    ]
  end
end

# --- Virt-Install Command ---

# Represents the `virt-install` command for creating and starting a libvirt VM.
class VirtInstall < Command
  # Builds the command array for `virt-install`.
  # Expects config fields: :selected_iso, :selected_drive, :vcpus, :memory
  # @return [Array<String>] The command array.
  def build_command_array
    [
      'sudo', # virt-install typically requires sudo
      'virt-install',
      '--osinfo', 'detect=on,name=archlinux', # Example, adjust as needed
      '--cdrom', config.selected_iso,
      '--disk', config.selected_drive, # Assumes path is correct
      '--cpu', 'host',
      '--memory', config.memory.to_s,
      '--vcpus', config.vcpus.to_s,
      '--network', 'default' # Example, adjust as needed
      # Add other necessary virt-install options like --name, --graphics, etc.
    ]
  end
end

# --- QEMU Image Command ---

# Represents the `qemu-img` command for creating disk images.
class QemuImg < Command
  # Builds the command array for `qemu-img create`.
  # Expects config fields: :drive_path, :size_gb
  # @return [Array<String>] The command array.
  def build_command_array
    [
      'qemu-img',
      'create',
      '-f', 'qcow2',
      config.drive_path,
      "#{config.size_gb}G"
    ]
  end
end

# --- Helper Functions ---

# Sets up the necessary environment directories and finds existing ISO and disk image files.
#
# @param app_root [String] The root directory of the application.
# @return [OpenStruct] An object containing paths to folders (`iso_folder`, `drive_folder`)
#   and lists of found files (`iso_files`, `drive_files`).
def setup_environment(app_root)
  iso_folder = File.join(app_root, 'out')
  drive_folder = File.join(app_root, 'qcow2')

  FileUtils.mkdir_p(drive_folder) unless Dir.exist?(drive_folder)

  iso_files = Dir.glob(File.join(iso_folder, '*.iso')).sort
  drive_files = Dir.glob(File.join(drive_folder, '*.qcow2')).sort

  OpenStruct.new(
    iso_folder: iso_folder,
    drive_folder: drive_folder,
    iso_files: iso_files,
    drive_files: drive_files
  )
end

# Prompts the user for VM configuration details, including QEMU command choice,
# vCPUs, memory, and disk selection/creation. If a new disk is created,
# the `qemu-img` command is executed immediately.
#
# @param prompt [TTY::Prompt] The TTY::Prompt instance for user interaction.
# @param env_config [OpenStruct] The environment configuration from {#setup_environment}.
# @return [OpenStruct] An object containing the user's selected configuration
#   (:qemu_choice, :vcpus, :memory, :selected_drive, :selected_iso, etc.).
def get_user_configuration(prompt, env_config)
  config = OpenStruct.new

  config.qemu_choice = prompt.select('Select QEMU command:', %w[virt-install qemu-system-x86_64])
  config.vcpus = prompt.ask('Enter the number of vCPUs:', default: '2') # Add default
  config.memory = prompt.ask('Enter the memory size (in MB):', convert: :int, default: 2048) # Add default

  create_new_disk = prompt.yes?('Create a new QEMU disk?')

  if create_new_disk
    drive_name = prompt.ask('Enter a name for the new QEMU disk (without extension):') do |q|
      q.required true
      q.validate ->(input) { !input.strip.empty? }, 'Name cannot be empty'
    end
    drive_name += '.qcow2'
    config.drive_path = File.join(env_config.drive_folder, drive_name)
    config.size_gb = prompt.ask('Enter the size of the new QEMU disk (in GB):', convert: :int, default: 20) # Add default

    # Execute disk creation immediately
    puts "\nCreating new disk..."
    qemu_img_cmd = QemuImg.new(config)
    qemu_img_cmd.execute
    puts "Disk created at #{config.drive_path}"

    # Add the new drive to the list for selection
    env_config.drive_files << config.drive_path
    env_config.drive_files.sort! # Keep it sorted
    config.selected_drive = config.drive_path # Pre-select the newly created drive
  else
    if env_config.drive_files.empty?
      puts "No existing drive files found in #{env_config.drive_folder}. Please create one first."
      exit 1
    end
    config.selected_drive = prompt.select('Select drive file:', env_config.drive_files)
  end

  if env_config.iso_files.empty?
    puts "No ISO files found in #{env_config.iso_folder}."
    exit 1
  end
  config.selected_iso = prompt.select('Select ISO file:', env_config.iso_files)

  # No need to Shellwords.escape here, as exec handles separate arguments
  config
end

# --- Main Execution ---

# Script entry point.
prompt = TTY::Prompt.new
environment = setup_environment(APP_ROOT)
user_config = get_user_configuration(prompt, environment)

puts "\nStarting VM..."

command = case user_config.qemu_choice
          when 'virt-install'
            VirtInstall.new(user_config)
          when 'qemu-system-x86_64'
            QemuSystem.new(user_config)
          else
            # Should not happen with TTY::Prompt select
            raise "Invalid QEMU choice: #{user_config.qemu_choice}"
          end

command.execute
