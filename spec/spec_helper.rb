# This file was generated by the `rspec --init` command. Conventionally, all
# specs live under a `spec` directory, which RSpec adds to the `$LOAD_PATH`.
# Require this file using `require "spec_helper.rb"` to ensure that it is only
# loaded once.
#

require_relative '../lib/arachni/ui/cli/output'
require_relative '../lib/arachni'

@@root = File.dirname( File.absolute_path( __FILE__ ) ) + '/'

@@server_pids ||= []
@@servers     ||= {}
Dir.glob( @@root + 'servers/*' ) {
    |path|

    name = File.basename( path, '.rb' ).to_sym
    next if name == :base

    @@servers[name] = {
        port: 5555 + rand( 9999 ),
        path: path
    }
}

def require_from_root( path )
    require Arachni::Options.instance.dir['lib'] + path
end


def require_testee!
    require Kernel::caller.first.split( ':' ).first.gsub( '/spec/arachni', '/lib/arachni' ).gsub( '_spec', '' )
end

def server_port_for( name )
    @@servers[name][:port]
end

def server_url_for( name )
    'http://localhost:' + server_port_for( name ).to_s
end

def start_servers!
    @@servers.each {
        |name, info|
        @@server_pids << fork {
            exec 'ruby', @@root + "servers/#{name}.rb", '-p ' + info[:port].to_s
        }
    }

    require 'net/http'
    begin
        Timeout::timeout( 10 ) do
            loop do

                up = 0
                @@servers.keys.each {
                    |name|

                    url = server_url_for( name )
                    begin
                        response = Net::HTTP.get_response( URI.parse( url ) )
                        up += 1 if response.is_a?( Net::HTTPSuccess )
                    rescue SystemCallError => error
                    end

                }

                if up == @@servers.size
                    puts 'Servers are up!'
                    return
                end

            end
        end
    rescue Timeout::Error => error
        abort "Server never started!"
    end
end


def reload_servers!
    kill_servers!
    start_servers!
end


def kill_servers!
    @@server_pids.each { |pid| Process.kill( 'INT', pid ) if pid }
end

# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|
    config.treat_symbols_as_metadata_keys_with_true_values = true
    config.run_all_when_everything_filtered = true
    config.filter_run :focus
    config.color = true
    config.add_formatter :documentation

    config.before( :suite ) do
        start_servers!
    end

    config.after( :suite ) do
        kill_servers!
    end
end
