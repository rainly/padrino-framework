module Padrino
  module Tasks
    module Adapter

      class << self
        ADAPTERS = %w[thin mongrel webrick]

        def start(options)

          chdir(options.chdir) if options.chdir

          ENV["PADRINO_ENV"] = options.environment.to_s

          require  'config/boot'

          puts "=> Padrino/#{Padrino.version} has taken the stage #{options.environment} on port #{options.port}"

          if options.daemonize?
            unless fork
              puts "=> Daemonized mode is not supported on your platform." 
              exit 
            end

            stop # We need to stop a process if exist

            fork do
              Process.setsid
              exit if fork
              File.umask 0000
              puts "=> Padrino is daemonized with pid #{Process.pid}"
              STDIN.reopen "/dev/null"
              STDOUT.reopen "/dev/null", "a"
              STDERR.reopen STDOUT

              chdir(options.chdir) if options.chdir

              FileUtils.mkdir_p("tmp/pids") unless File.exist?("tmp/pids")
              pid = "tmp/pids/server.pid"

              if pid
                File.open(pid, 'w'){ |f| f.write("#{Process.pid}") }
                at_exit { File.delete(pid) if File.exist?(pid) }
              end

              run_app(options)

            end
          else
            run_app(options)
          end
        end

        def chdir(dir)
          begin
            Dir.chdir(dir.to_s)
          rescue Errno::EACCES
            puts "=> You specified Padrino root as #{dir}, " +
                 "yet the current user does not have access to it."
          end
        end

        def run_app(options)

          handler_name = options.adapter.to_s.capitalize

          begin
            handler = Rack::Handler.get(handler_name.downcase)
          rescue
            puts "#{handler_name} not supported yet, available adapter are: #{ADAPTERS.inspect}"
            exit
          end
          
          handler.run Padrino.application, :Host => options.host, :Port => options.port do |server|
            trap(:INT) do
              # Use thins' hard #stop! if available, otherwise just #stop
              server.respond_to?(:stop!) ? server.stop! : server.stop
              puts "<= Padrino has ended his set (crowd applauds)"
            end
          end
        rescue Errno::EADDRINUSE
          puts "=> Someone is already performing on port #{options.port}!"
        end

        def stop(dir=nil)
          chdir(dir) if dir
          if File.exist?("tmp/pids/server.pid")
            pid = File.read("tmp/pids/server.pid").to_i
            print "=> Sending SIGTERM to process with pid #{pid} wait "
            Process.kill(15, pid) rescue nil
            1.step(5) { |i| sleep i; print "."; $stdout.flush }
            puts " done."
          end
        end

      end
    end
  end
end