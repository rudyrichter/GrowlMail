#!/usr/bin/ruby
=begin
 Copyright (c) 2011-2014, Rudy Richter.
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 3. Neither the name of Growl nor the names of its contributors
 may be used to endorse or promote products derived from this software
 without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 OF THE POSSIBILITY OF SUCH DAMAGE.
 =end

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