#!/usr/bin/ruby

require 'find'
require 'fileutils'
require 'getoptlong'

languages=nil
opts = GetoptLong.new(
                      [ "--valid-languages", "-l", GetoptLong::REQUIRED_ARGUMENT ]
                      )
opts.each do |opt, arg|
	case opt
		when "--valid-languages"
        languages = arg.split(",")
	end
end

Find.find(ARGV.shift) do |path|
    if File.extname(path) == '.lproj'
        unless languages.include?(File.basename(path, '.lproj'))
            puts "Deleting #{path}"
            FileUtils.rm_r(path)
        end
        Find.prune
    end
end