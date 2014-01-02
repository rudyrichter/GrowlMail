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

def sign(path,signer)
	problem = false
	command = ['codesign', '--preserve-metadata=identifier,entitlements,resource-rules', '-f', '-s', "\""+signer+"\"", "\""+path+"\""]
	system command.join(' ')
	status = $?
	if status.exitstatus != 0
		puts "Failed to run: #{command}"
		problem = true
	end
	return problem
end

def resign(path, signer)
	problem = false
	if not File.exists? path
		puts "No such file #{path}"
		problem = true
		return problem
	end
    
	Find.find(path) do |subpath|
		fileCheck = %x{/usr/bin/file -h "#{subpath}"}
		if fileCheck.include? "Mach-O"
			#we found a binary now lets call codesign on it and see if it has the right signer
			problem = sign(subpath, signer)
		elsif path[-10..-1] == '.framework'
    		versions = Dir.glob(path+"/Versions/*")
    		for version in versions
      			if File.basename(version) != 'Current'       
      		          problem = resign(version, signer)
        		end
 			end
		end
	end
	return problem
end

def main
    signer = "3rd Party Mac Developer Application: The Growl Project, LLC"
	path = ARGV[0]
	opts = GetoptLong.new(
                          [ "--signing-identity", "-i", GetoptLong::REQUIRED_ARGUMENT ]
                          )
	opts.each do |opt, arg|
        case opt
            when "--signing-identity"
			signer = arg
		end
	end
    resign(path, signer)
end

if __FILE__ == $0
	main()
end