/*--
 * Copyright (c) 2006, 2007, 2008 Andre Nathan <andre@digirati.com.br>
 * 
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 * $Id$
 *++
 */

/*
 * Document-class: Watchcat
 *
 * == Overview
 *
 * Ruby/Watchcat is a library for the development of watchcatd-aware
 * applications. It requires watchcatd to be installed and running, and
 * communicates with it via UNIX sockets.
 *
 */

#include <ruby.h>
#include <watchcat.h>

#define SYMBOL(s) ID2SYM(rb_intern(s))

/*
 * call-seq:
 *   Watchcat.new([options])                      => watchcat_obj
 *   Watchcat.new([options]) { |watchcat| block } => watchcat_obj
 *
 * Create a new Watchcat object. The parameter hash may have the following
 * symbols:
 * +timeout+::
 *   If watchcatd doesn't receive a heartbeat after this period (in seconds),
 *   it will signal the process. (default: 60)
 * +signal+::
 *   Defines which signal will be sent to the process after the timeout
 *   expires. Can be a string like 'HUP' or 'SIGHUP' or an integer like 9.
 *   (default: 9)
 * +info+::
 *   Should be a string which is added to the log generated by watchcatd
 *   when it signals a process. (default: nil)
 * +device+::
 *   The watchcat device. (default: +/var/run/watchcat.socket+). Use for
 *   debugging purposes.
 *
 * If a block is given, the Watchcat object will be yielded and automatically
 * closed on block termination.
 */
static VALUE
rb_wcat_open(int argc, VALUE *argv, VALUE self)
{
    int sock, timeout, signal;
    char *signame;
    const char *info;
    VALUE opt, vtimeout, vsignal, vinfo, vdevice, vsiglist, mSignal;

    rb_scan_args(argc, argv, "01", &opt);
    if (NIL_P(opt)) {
        sock = cat_open();
        if (sock == -1)
            rb_sys_fail("cat_open");
        rb_iv_set(self, "@sock", INT2NUM(sock));
        return(self);
    }

    /* Defaults. */
    timeout = 60;
    signal = SIGKILL;
    info = NULL;
    
    vtimeout = rb_hash_aref(opt, SYMBOL("timeout"));
    if (!NIL_P(vtimeout)) {
        if (FIXNUM_P(vtimeout))
            timeout = NUM2INT(vtimeout);
        else
            rb_raise(rb_eArgError, "timeout must be an integer");
    }

    vsignal = rb_hash_aref(opt, SYMBOL("signal"));
    if (!NIL_P(vsignal)) {
        switch (TYPE(vsignal)) {
        case T_FIXNUM:
            signal = NUM2INT(vsignal);
            break;
        case T_STRING:
            signame = StringValuePtr(vsignal);
            if (strncmp("SIG", signame, 3) == 0) {
                signame += 3;
                vsignal = rb_str_new2(signame);
            }
            mSignal = rb_const_get(rb_cObject, rb_intern("Signal"));
            vsiglist = rb_funcall(mSignal, rb_intern("list"), 0);
            vsignal = rb_hash_aref(vsiglist, vsignal);
            if (NIL_P(vsignal))
                rb_raise(rb_eArgError, "invalid signal name");
            else
                signal = NUM2INT(vsignal);
            break;
        default:
            rb_raise(rb_eArgError, "signal must be an integer or a string");
        }
    }

    vinfo = rb_hash_aref(opt, SYMBOL("info"));
    if (!NIL_P(vinfo))
        info = StringValuePtr(vinfo);

    vdevice = rb_hash_aref(opt, SYMBOL("device"));
    if (!NIL_P(vdevice))
        cat_set_device(StringValuePtr(vdevice));

    sock = cat_open1(timeout, signal, info);
    if (sock == -1)
        rb_sys_fail("cat_open");

    rb_iv_set(self, "@sock", INT2NUM(sock));

    if (rb_block_given_p())
        rb_ensure(rb_yield, self, (void *)cat_close, sock);

    return(self);
}

/*
 * call-seq:
 *   cat.heartbeat
 *
 * Send a heartbeat to watchcatd, telling it we're still alive.
 */
static VALUE
rb_wcat_heartbeat(VALUE self)
{
    VALUE sock = rb_iv_get(self, "@sock");
    if (cat_heartbeat(NUM2INT(sock)) == -1)
        rb_sys_fail("cat_heartbeat");
    return(Qnil);
}

/*
 * call-seq:
 *   cat.close
 *
 * Close communication with watchcatd.
 */
static VALUE
rb_wcat_close(VALUE self)
{
    VALUE sock = rb_iv_get(self, "@sock");
    if (cat_close(NUM2INT(sock)) == -1)
        rb_sys_fail("cat_close");
    return(Qnil);
}

void
Init_watchcat(void)
{
    VALUE cWCat = rb_define_class("Watchcat", rb_cObject);

    rb_define_method(cWCat, "initialize", rb_wcat_open, -1);
    rb_define_alias(cWCat, "open", "initialize");
    rb_define_method(cWCat, "heartbeat", rb_wcat_heartbeat, 0);
    rb_define_method(cWCat, "close", rb_wcat_close, 0);
}
