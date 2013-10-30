#!/usr/bin/ruby

class PlistBuddy
    BIN = '/usr/libexec/PlistBuddy'
    
    def initialize(plist)
        @plist = plist
    end
    
    def [](prop)
        value = `#{BIN} -c 'Print :#{prop}' #{@plist} 2>/dev/null`
        $?.success? ? value.strip : nil
    end
    
    def []=(prop, val)
        if val.nil?
            `#{BIN} -c 'Delete :#{prop}' #{@plist} 2>/dev/null`
            else
            prev = self[prop]
            if prev.nil?
                `#{BIN} -c 'Add :#{prop} string #{val}' #{@plist} 2>/dev/null`
                else
                `#{BIN} -c 'Set :#{prop} #{val}' #{@plist} 2>/dev/null`
            end
        end
        
        val
    end
end
