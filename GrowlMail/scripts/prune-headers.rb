#!/usr/bin/ruby

require 'find'
require 'fileutils'

Find.find(ARGV.shift) do |path|
    if File.basename(path) == 'Headers' or
       File.basename(path) == 'PrivateHeaders'
            puts "Deleting #{path}"
            FileUtils.rm_r(path)
        Find.prune
    end
end