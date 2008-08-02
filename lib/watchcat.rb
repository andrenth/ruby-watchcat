#
# Copyright (c) 2008 Andre Nathan <andre@digirati.com.br>
# 
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
# 
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#
# $Id$
#

# Pure-ruby version of libwcat.

require 'fcntl'
require 'socket'

class Watchcat
  DEFAULT_TIMEOUT = 60
  DEFAULT_DEVICE  = '/dev/watchcat'
  DEFAULT_SIGNAL  = Signal.list['KILL']

  def initialize(args = {})
    timeout = args[:timeout] || DEFAULT_TIMEOUT
    device  = args[:device] || DEFAULT_DEVICE
    info    = args[:info] ? args[:info].to_s : ''

    unless timeout.is_a? Fixnum
      raise ArgumentError, 'timeout must be an integer'
    end

    case args[:signal]
    when nil
      signal = DEFAULT_SIGNAL
    when String
      signal = Signal.list[args[:signal].sub(/^SIG_/, '')]
      raise ArgumentError, "invalid signal name" if signal.nil?
    when Fixnum
      signal = args[:signal]
    else
      raise ArgumentError, "signal must be an integer or a string"
    end

    @sock = UNIXSocket.new(device)
    @sock.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)

    msg = "version: 1\ntimeout: #{timeout}\nsignal: #{signal}"
    if info.nil?
      msg << "\n\n"
    else
      info.gsub!(/\n/, '_')
      msg << "\ninfo: #{info}\n\n"
    end

    safe_write(@sock, msg)
    if safe_read(@sock, 256) == "ok\n"
      if  block_given?
        begin
          yield(self)
        ensure
          @sock.close
        end
      end
      return self
    else
      @sock.close
      # Probably not the best error, but it matches the C library.
      raise Errno::EPERM
    end
  end

  def heartbeat
    safe_write(@sock, '.')
  end

  def close
    begin
      @sock.close
    rescue Errno::EINTR
      retry
    end
  end

private

  def safe_write(fd, buf)
    act = Signal.trap('PIPE', 'IGN')
    begin
      fd.syswrite(buf)
    rescue Errno::EINTR
      retry
    end
    Signal.trap('PIPE', act)
  end

  def safe_read(fd, len)
    buf = ''
    begin
      buf = fd.sysread(len)
    rescue Errno::EINTR
      retry
    end
    return buf
  end
end
