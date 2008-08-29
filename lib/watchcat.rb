#--
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
#++

# Pure-ruby version of libwcat.

require 'fcntl'
require 'socket'

#
# == Overview
#
# Ruby/Watchcat is a library for the development of watchcatd-aware
# applications. It requires watchcatd to be installed and running, and
# communicates with it via UNIX sockets.
#
class Watchcat
  DEFAULT_TIMEOUT = 60
  DEFAULT_DEVICE  = '/var/run/watchcat.socket'
  DEFAULT_SIGNAL  = Signal.list['KILL']

  # Create a new Watchcat object. The parameter hash may have the following
  # symbols:
  # +timeout+::
  #   If watchcatd doesn't receive a heartbeat after this period (in seconds),
  #   it will signal the process. (default: 60)
  # +signal+::
  #   Defines which signal will be sent to the process after the timeout
  #   expires. Can be a string like 'HUP' or 'SIGHUP' or an integer like 9.
  #   (default: 9)
  # +info+::
  #   Should be a string which is added to the log generated by watchcatd
  #   when it signals a process. (default: nil)
  # +device+::
  #   The watchcat device. (default: +/var/run/watchcat.socket+). Use for
  #   debugging purposes.
  #
  # If a block is given, the Watchcat object will be yielded and automatically
  # closed on block termination.
  def initialize(args = {}) # :yield:
    timeout = args[:timeout] || DEFAULT_TIMEOUT
    device  = args[:device] || DEFAULT_DEVICE
    info    = args[:info] ? args[:info].to_s : ''

    unless timeout.is_a? Fixnum
      raise ArgumentError, 'timeout must be an integer'
    end

    signal = signal_number(args[:signal])
    @sock  = create_socket(device)
    msg    = build_message(timeout, signal, info)

    safe_write(@sock, msg)
    unless safe_read(@sock, 256) == "ok\n"
      @sock.close
      # Probably not the best error, but it matches libwcat.
      raise Errno::EPERM
    end

    if block_given?
      begin
        yield(self)
      ensure
        @sock.close
      end
    end
    return self
  end

  # Send a heartbeat to watchcatd, telling it we're still alive.
  def heartbeat
    safe_write(@sock, '.')
    return nil
  end

  # Close communication with watchcatd.
  def close
    begin
      @sock.close
    rescue Errno::EINTR
      retry
    end
    return nil
  end

private

  def signal_number(value)
    case value
    when nil
      signal = DEFAULT_SIGNAL
    when String
      signal = Signal.list[args[:signal].sub(/^SIG/, '')]
      raise ArgumentError, "invalid signal name" if signal.nil?
    when Fixnum
      signal = args[:signal]
    else
      raise ArgumentError, "signal must be an integer or a string"
    end
  end

  def create_socket(device)
    sock = UNIXSocket.new(device)
    if Fcntl.const_defined? :F_SETFD
      sock.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)
    end
    return sock
  end

  def build_message(timeout, signal, info)
    msg = "version: 1\ntimeout: #{timeout}\nsignal: #{signal}"
    if info.nil?
      msg << "\n\n"
    else
      info.gsub!(/\n/, '_')
      msg << "\ninfo: #{info}\n\n"
    end
    return msg
  end

  def safe_write(fd, buf)
    act = Signal.trap('PIPE', 'IGN')
    begin
      if RUBY_PLATFORM =~ /freebsd/i
        FreeBSD.sendmsg(fd, " #{buf}")  # XXX prepend an extra byte
      else
        fd.syswrite(buf)
      end
    rescue Errno::EINTR
      retry
    ensure
      Signal.trap('PIPE', act)
    end
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

module FreeBSD # :nodoc:
  extend(self)

  INT_SIZE    = [0].pack("i_").size
  INT32_SIZE  = 4
  SHORT_SIZE  = [0].pack("s_").size
  CMGROUP_MAX = 16
  ALIGNBYTES  = [0].pack("L_").size - 1

private

  def align(p, alignbytes = ALIGNBYTES)
    (p + alignbytes) & ~alignbytes
  end

  def sizeof(p)
    align(p, 3)
  end

  #
  # This code depends on structs cmsghdr and cmsgcred being as shown below.
  # It also depends on sendmsg(2) being syscall number 28 and on the
  # SOL_SOCKET and SCM_CREDS macros having the same values as the constants
  # defined below.
  #
  # struct cmsghdr {
  #   socklen_t cmsg_len;  /* __uint32_t */
  #   int   cmsg_level;    /* int        */
  #   int   cmsg_type;     /* int        */
  # };
  #
  # struct cmsgcred {
  #   pid_t cmcred_pid;                    /* __int32_t       */
  #   uid_t cmcred_uid;                    /* __uint32_t      */
  #   uid_t cmcred_euid;                   /* __uint32_t      */
  #   gid_t cmcred_gid;                    /* __uint32_t      */
  #   short cmcred_ngroups;                /* short           */
  #   gid_t cmcred_groups[CMGROUP_MAX];    /* __uint32_t * 16 */
  # };
  #

  SYS_SENDMSG = 28
  SOL_SOCKET  = 0xffff
  SCM_CREDS   = 0x03

  CMSGCRED_SIZE = sizeof(4*INT_SIZE + SHORT_SIZE + CMGROUP_MAX * INT32_SIZE)
  CMSGHDR_SIZE  = sizeof(INT32_SIZE + 2 * INT_SIZE)

public
 
  def sendmsg(fd, buf)
    iov = [buf, buf.length].pack("pL_")

    cmsg_space    = cmsg_space(CMSGCRED_SIZE)
    cmsg_data_len = cmsg_space - INT32_SIZE - 2*INT_SIZE

    cmsghdr = ([
      cmsg_len(CMSGCRED_SIZE), # cmsg_len
      SOL_SOCKET,              # cmsg_level
      SCM_CREDS                # cmsg_type
    ] + [0] * cmsg_data_len).pack("I_i_i_C#{cmsg_data_len}")

    msg_control_ptr = pointer(cmsghdr)
    msg_controllen = cmsg_space

    msghdr = [
      0,                # msg_name
      0,                # msg_namelen
      pointer(iov),     # msg_iov
      1,                # msg_iovlen
      pointer(cmsghdr), # msg_control
      cmsg_space,       # msg_controllen
      0                 # msg_flags
    ].pack("L_L_L_L_L_L_L_")

    syscall(SYS_SENDMSG, fd.fileno, pointer(msghdr), 0)
  end

private

  def pointer(buf)
    [buf].pack("P").unpack("L_").first
  end

  def cmsg_len(l)
    align(CMSGHDR_SIZE) + l
  end
  
  def cmsg_space(l)
    align(CMSGHDR_SIZE) + align(l)
  end
end
