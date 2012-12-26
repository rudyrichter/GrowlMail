#!/usr/bin/ruby

require 'find'
require 'fileutils'
require 'getoptlong'

build_dir = ENV['BUILT_PRODUCTS_DIR']
executable_path = ENV['EXECUTABLE_PATH']

command = ['install_name_tool', '-change', '@executable_path/../Frameworks/Growl.framework/Versions/A/Growl', '@loader_path/../Frameworks/Growl.framework/Versions/A/Growl', "#{build_dir}/#{executable_path}"]
system command.join(" ")

command = ['install_name_tool', '-id', '@loader_path/../Frameworks/Growl.framework/Versions/A/Growl', "#{build_dir}/#{executable_path}/Contents/Frameworks/Growl.framework/Growl"]
system command.join(" ")