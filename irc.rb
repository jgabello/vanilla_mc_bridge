#!/usr/bin/env ruby

require 'socket'
require 'uri'

class MinecraftIrcBot
  def initialize(options)
    uri = URI.parse("irc://#{options[:server]}")
    #@channel = options[:channel]
    @channel = "minecraft"
    @socket = TCPSocket.open(uri.host, uri.port || 6667)
    @mclog = IO.popen("tail -f -n0 '#{options[:log]}'", "r")
    @name = options[:name]
    @pipe = options[:pipe]
    say "NICK #{@name}"
    say "USER #{@name} 0 * #{@name}"
  end

  def say(msg)
    puts msg
    @socket.puts msg
  end

  def say_to_chan(msg)
    say "PRIVMSG ##{@channel} :#{msg}"
  end

  def say_to_minecraft(msg)
    msg = "say #{msg}"
    puts msg

    File.open(@pipe, "w") do |console|
      console.puts msg
    end
  end

  def killplayer(player)
    msg = "kill #{player}"
    puts msg
    File.open(@pipe, "w") do |console|
      console.puts msg
    end
  end

  def run
    loop do
      read, write, error = IO.select([@socket, @mclog])
      if read.include? @socket
        msg = @socket.gets

        puts msg

        # connection lost
        return unless msg

        case msg.strip
        when /^PING :(.+)$/i
          say "PONG #{$1}"
        when /^:(.+?)!.+?@.+?\sPRIVMSG\s.+?\s:(.+)$/i
          say_to_minecraft("<#{$1}> #{$2}")
      end

      if read.include? @mclog
        msg = @mclog.gets
        msg.gsub!(/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} /, '')
        case msg.strip
          when /^.*<syclopa> \.ircload/
            say("JOIN #minecraft")
            say("PART #helpdesk")
          when /^.*<([a-z0-9]*)> \.kill/
            killplayer("#{$1}")
          when /^.*_to<([a-z0-9]*)> (.*)$/i
            say_to_chan("<#{$1}> #{$2}")
          when /^.*INFO\]:\s([a-z0-9]*) lost connection/i
            say_to_chan("* #{$1} has left the game")
          when /^\[INFO\] ([a-z0-9]*)\[[^\]]*\] logged in/i
            say_to_chan("* #{$1} has joined the game")
          when /^\[INFO\] ([a-z0-9]*) was slain by ([a-z0-9]*)/i
            say_to_chan("* #{$1} was slain by #{$2}")
          when /^\[INFO\] ([a-z0-9]*) drowned/i 
            say_to_chan("* #{$1} drowned")
          when /^\[INFO\] ([a-z0-9]*) fell from a high place/i 
            say_to_chan("* #{$1} fell from a high place")
          when /^\[INFO\] ([a-z0-9]*) tried to swim in lava/i 
            say_to_chan("* #{$1} tried to swim in lava")
        end
      end
    end
  end

  def quit
    say "PART ##{@channel} :bye bye"
    say 'QUIT'
  end
end


def parse
  require 'optparse'
  options = {}
  optparse = OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} options"

    opts.on("-s", "--server SERVER", "IRC server") do |v|
      options[:server] = v
    end
    opts.on("-c", "--channel CHAN", "IRC channel") do |v|
      options[:channel] = v
    end
    opts.on("-f", "--fifo FIFO", "named pipe into minecraft server's console") do |v|
      options[:pipe] = v
    end
    opts.on("-l", "--log LOG", "minecraft servers's log file for reading") do |v|
      options[:log] = v
    end

    options[:name] = "mcirc"
    opts.on("-n", "--name NAME", "name of the irc user") do |v|
      options[:name] = v
    end
  end
  begin
    optparse.parse!

    required = [:server, :channel, :pipe, :log]
    required.each do |arg|
      raise OptionParser::MissingArgument, arg if options[arg].nil?
    end
  rescue OptionParser::InvalidOption, OptionParser::MissingArgument
    puts $!.to_s
    puts optparse
    exit 1
  end
  options
end

def run
  options = parse
  bot = MinecraftIrcBot.new(options)

  trap("INT"){ bot.quit }

  bot.run
end

run
