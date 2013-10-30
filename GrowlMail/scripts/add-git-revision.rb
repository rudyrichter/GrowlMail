#!/usr/bin/ruby
require 'find'
require 'fileutils'
require 'getoptlong'
require File.dirname(__FILE__) +'/plist-buddy.rb'

def git_clean
    clean = %x{git status --porcelain}
    return clean.length == 0
end

def git_hash
    hash = %x{git rev-parse HEAD};
    return hash
end

def add_git_hash(app_base, hash)
    contents_path = File.join(app_base, "Contents")
    info_path = File.join(contents_path, "Info.plist")
    
    #get the app's bundle id, this will be our base ID
    plist = PlistBuddy.new(info_path)
    plist['BRCommitHash'] = hash
end

def main
	path = ARGV[0]
    configuration = ENV['CONFIGURATION']

    if configuration == 'Release'
        if(git_clean())
            add_git_hash(path, git_hash())
        else
            raise "working directory is not clean"
        end
    end
end

if __FILE__ == $0
	main()
end