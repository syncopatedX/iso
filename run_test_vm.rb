#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'tty-prompt'
require 'shellwords'

HOME = ENV['HOME']

class QemuCommand
  def execute
    raise NotImplementedError, "#{self.class} has not implemented the execute method"
  end
end

class QemuSystemCommand < QemuCommand
  def initialize(selected_iso, selected_drive, vcpus, memory)
    @selected_iso = selected_iso
    @selected_drive = selected_drive
    @vcpus = vcpus
    @memory = memory
  end

  def execute
    command = "qemu-system-x86_64 -cdrom #{@selected_iso} -cpu host -enable-kvm -m #{@memory} -smp #{@vcpus} -drive file=#{@selected_drive},format=qcow2 -device intel-hda"
    puts "Executing command: #{command}"

    # Fork the process to execute the command
    pid = fork do
      exec(command)
    end

    # Wait for the child process to finish
    Process.wait(pid)
  end
end

class VirtInstallCommand < QemuCommand
  def initialize(selected_iso, selected_drive, vcpus, memory)
    @selected_iso = selected_iso
    @selected_drive = selected_drive
    @vcpus = vcpus
    @memory = memory
  end

  def execute
    command = "sudo virt-install --osinfo detect=on,name=archlinux --cdrom #{@selected_iso} --disk #{@selected_drive} --cpu host --memory #{@memory} --vcpus #{@vcpus} --network default"
    puts "Executing command: #{command}"

    # Fork the process to execute the command
    pid = fork do
      exec(command)
    end

    # Wait for the child process to finish
    Process.wait(pid)
  end
end

class QemuImgCommand < QemuCommand
  def initialize(drive_path, size)
    @drive_path = drive_path
    @size = size
  end

  def execute
    qemu_img_command = "qemu-img create -f qcow2 #{@drive_path} #{@size}G"
    puts "Executing command: #{qemu_img_command}"

    # Fork the process to execute the command
    pid = fork do
      exec(qemu_img_command)
    end

    # Wait for the child process to finish
    Process.wait(pid)
  end
end

prompt = TTY::Prompt.new

# iso_folder = prompt.ask("Folder name where isos are stored:") do |q|
#   q.required(true)
#   q.validate ->(v) { return !Dir.exist?(v) }
#   p q.messages
#   q.messages[:valid?] = "Folder exists"
#   q.messages[:required?] = "Folder name must not be empty"
# end
#
# drive_folder = prompt.ask("Folder name where qcow disks are stored:") do |q|
#   q.required(true)
#   q.validate ->(v) { return !Dir.exist?(v) }
#   q.messages[:valid?] = "Folder already exists?"
#   q.messages[:required?] = "Folder name must not be empty"
# end

iso_folder = File.join(HOME, 'Workspace', 'Ansible', 'syncopatedOS', 'roles', 'iso', 'files', 'out')
drive_folder = File.join(HOME, 'Workspace', 'Ansible', 'syncopatedOS', 'roles', 'iso', 'files', 'qcow2')

FileUtils.mkdir_p(drive_folder) unless Dir.exist?(drive_folder)

iso_files = Dir.glob(File.join(iso_folder, '*.iso')).sort
drive_files = Dir.glob(File.join(drive_folder, '*.qcow2')).sort

# Prompt to choose between virt-install and qemu-system-x86_64
qemu_choice = prompt.select('Select QEMU command:', %w[virt-install qemu-system-x86_64])

# Prompt for vCPUs and memory
vcpus = prompt.ask('Enter the number of vCPUs:')
memory = prompt.ask('Enter the memory size (in MB):', convert: :int)

# Prompt to choose between creating a new disk or selecting an existing one
create_new_disk = prompt.yes?('Create a new QEMU disk?')

if create_new_disk
  drive_name = prompt.ask('Enter a name for the new QEMU disk (without extension):')
  drive_name += '.qcow2'
  drive_path = File.join(drive_folder, drive_name)

  size = prompt.ask('Enter the size of the new QEMU disk (in GB):', convert: :int)

  command = QemuImgCommand.new(drive_path, size)
  command.execute

  drive_files << drive_path # Add the newly created drive to the array

  selected_iso = Shellwords.escape(prompt.select('Select ISO file:', iso_files))
  selected_drive = Shellwords.escape(prompt.select('Select drive file:', drive_files))

  command = if qemu_choice == 'virt-install'
              VirtInstallCommand.new(selected_iso, selected_drive, vcpus, memory)
            else
              QemuSystemCommand.new(selected_iso, selected_drive, vcpus, memory)
            end

  command.execute
else
  # Prompt to choose ISO and drive files
  if qemu_choice == 'virt-install'
    selected_iso = Shellwords.escape(prompt.select('Select ISO file:', iso_files))
    selected_drive = Shellwords.escape(prompt.select('Select drive file:', drive_files))

    command = VirtInstallCommand.new(selected_iso, selected_drive, vcpus, memory)
    command.execute
  else
    selected_iso = Shellwords.escape(prompt.select('Select ISO file:', iso_files))
    selected_drive = Shellwords.escape(prompt.select('Select drive file:', drive_files))

    command = QemuSystemCommand.new(selected_iso, selected_drive, vcpus, memory)
    command.execute
  end
end
