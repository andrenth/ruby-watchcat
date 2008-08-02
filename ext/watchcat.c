/*
 * Copyright (c) 2006 Andre Nathan <andre@digirati.com.br>
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
 *
 */
#include <ruby.h>
#include <watchcat.h>

#define SYMBOL(s) ID2SYM(rb_intern(s))

static VALUE
rb_wcat_open(int argc, VALUE *argv, VALUE self)
{
    int sock, id, timeout, signal;
    char *signame;
    const char *info;
    VALUE opt, vtimeout, vsignal, vinfo, vsiglist, mSignal;

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
    
    vtimeout = rb_hash_aref(opt, ID2SYM(rb_intern("timeout")));
    if (!NIL_P(vtimeout)) {
        if (FIXNUM_P(vtimeout))
            timeout = NUM2INT(vtimeout);
        else
            rb_raise(rb_eTypeError, "timeout must be an integer");
    }

    vsignal = rb_hash_aref(opt, ID2SYM(rb_intern("signal")));
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
            id = rb_intern("Signal");
            mSignal = rb_const_get(rb_cObject, id);
            id = rb_intern("list");
            vsiglist = rb_funcall(mSignal, id, 0);
            id = rb_intern("fetch");
            vsignal = rb_funcall(vsiglist, id, 1, vsignal);
            signal = NUM2INT(vsignal);
            break;
        default:
            rb_raise(rb_eTypeError, "signal must be an integer or a string");
        }
    }

    vinfo = rb_hash_aref(opt, ID2SYM(rb_intern("info")));
    if (!NIL_P(vinfo))
        info = StringValuePtr(vinfo);

    sock = cat_open1(timeout, signal, info);
    if (sock == -1)
        rb_sys_fail("cat_open");

    rb_iv_set(self, "@sock", INT2NUM(sock));

    if (rb_block_given_p())
        rb_ensure(rb_yield, self, (void *)cat_close, sock);

    return(self);
}

static VALUE
rb_wcat_heartbeat(VALUE self)
{
    VALUE sock = rb_iv_get(self, "@sock");
    if (cat_heartbeat(NUM2INT(sock)) == -1)
        rb_sys_fail("cat_heartbeat");
    return(Qnil);
}

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
