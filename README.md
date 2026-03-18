# report-openssl-improve-ffc-params-error-messages

This repository is to manage the files related to
[this openssl ticket](https://github.com/openssl/openssl/issues/17108).

## Testing with OpenSSL

### My OpenSSL testing environment.

My testing environment is below.

OpenSSL (openssl/openssl)

```
$ OPENSSL_DIR="${HOME}/.local/openssl-4.1.0-dev-fips-debug-50724a9686-wip/"

$ ${OPENSSL_DIR}/bin/openssl version
OpenSSL 4.1.0-dev  (Library: OpenSSL 4.1.0-dev )

$ ${OPENSSL_DIR}/bin/openssl list -providers
Providers:
  default
    name: OpenSSL Default Provider
    version: 4.1.0
    status: active
```

```
$ cat $OPENSSL_DIR/ssl/openssl_fips.cnf
config_diagnostics = 1
openssl_conf = openssl_init

# It seems that the .include needs an absolute path.
.include /home/jaruga/.local/openssl-4.1.0-dev-fips-debug-50724a9686-wip/ssl/fipsmodule.cnf

[openssl_init]
providers = provider_sect
alg_section = algorithm_sect

[provider_sect]
fips = fips_sect
base = base_sect

[base_sect]
activate = 1

[algorithm_sect]
default_properties = fips=yes
```

```
$ OPENSSL_CONF=$OPENSSL_DIR/ssl/openssl_fips.cnf \
  ${OPENSSL_DIR}/bin/openssl list -providers
Providers:
  base
    name: OpenSSL Base Provider
    version: 4.1.0
    status: active
  fips
    name: OpenSSL FIPS Provider
    version: 4.1.0
    status: active
```

### Test with openssl commands

Tested the testing matrix, (DH, DSA) x (non-FIPS, FIPS) = 4 cases.

non-FIPS

```
$ $OPENSSL_DIR/bin/openssl genpkey -genparam -algorithm DHX \
  -pkeyopt pbits:512 -pkeyopt qbits:160 -pkeyopt dh_paramgen_type:2
genpkey: Generating DHX key parameters failed
40579372397F0000:error:0280007F:Diffie-Hellman routines:ffc_validate_LN:bad ffc parameters:crypto/ffc/ffc_params_generate.c:80:(L, N)=(512, 160) should be (1024, 160), (2048, 224) or (2048, 256)

$ $OPENSSL_DIR/bin/openssl dsaparam -genkey 512
-----BEGIN DSA PARAMETERS-----
MIGlAkEA71d52v5vxskYtZHXhaGVOxTRjCkpq6NNAoblN8tq1m1641Raee8Q0peL
ya7enZHY/2QVGfXXLn2rW3ctyUfz+wIdAK5nkupa0Si5W+JNQRt9FAzNjiX5scYS
jSs7ETUCQQCXwjN/nq8Mayg1bUfCcvUN41GvCSpgO38eehHJim0O294TBfz8q3Ir
S3g5riL1WQgc4bPQfNEMO9rT7aXn3oMx
-----END DSA PARAMETERS-----
dsaparam: Error generating DSA key
4057CB4F337F0000:error:05000072:dsa routines:ffc_validate_LN:bad ffc parameters:crypto/ffc/ffc_params_generate.c:92:(L, N)=(512, 224) should be at least (1024, 160)
```

FIPS

I couldn't test DSA FIPS case. See the Notes section for details.

```
$ OPENSSL_CONF=$OPENSSL_DIR/ssl/openssl_fips.cnf \
  $OPENSSL_DIR/bin/openssl genpkey -genparam -algorithm DHX \
  -pkeyopt pbits:512 -pkeyopt qbits:160 -pkeyopt dh_paramgen_type:2
genpkey: Generating DHX key parameters failed
40876AB9C07F0000:error:0280007F:Diffie-Hellman routines:ffc_validate_LN:bad ffc parameters:crypto/ffc/ffc_params_generate.c:49:(L, N)=(512, 160) should be (2048, 224) or (2048, 256)

$ OPENSSL_CONF=$OPENSSL_DIR/ssl/openssl_fips.cnf \
  $OPENSSL_DIR/bin/openssl genpkey -genparam -algorithm DSA \
  -pkeyopt pbits:2048 -pkeyopt qbits:220
genpkey: Generating DSA key parameters failed
40B7840EDF7F0000:error:030000E9:digital envelope routines:evp_keymgmt_gen:provider keymgmt failure:crypto/evp/keymgmt_meth.c:468:DSA key generation:OpenSSL DSA implementation
```

### Notes

#### Couldn't confirm the changed error message in the DSA FIPS case

I couldn't test the DSA FIPS case, to print the changed FFC parameters error message.
Because the case was rejected by
[this DSA sign disabled error](https://github.com/openssl/openssl/blob/e1eb88118a95445eb9c2d074c853776feaab4de7/providers/implementations/keymgmt/dsa_kmgmt.c#L627-L630).
The debug log is below.

```
$ gdb --args \
  $OPENSSL_DIR/bin/openssl genpkey -genparam -algorithm DSA \
  -pkeyopt pbits:2048 -pkeyopt qbits:220
...
(gdb) set environment OPENSSL_CONF=/home/jaruga/.local/openssl-4.1.0-dev-fips-debug-50724a9686-wip/ssl/openssl_fips.cnf
(gdb) b dsa_gen
...
(gdb) n
627	    if (!OSSL_FIPS_IND_ON_UNAPPROVED(gctx, OSSL_FIPS_IND_SETTABLE0,
(gdb) n
630	        return 0;
(gdb) f
#0  dsa_gen (genctx=0x58baf0, osslcb=0x7ffff7779313 <ossl_callback_to_pkey_gencb>,
    cbarg=0x5723c0) at providers/implementations/keymgmt/dsa_kmgmt.c:630
630	        return 0;
(gdb) bt
#0  dsa_gen (genctx=0x58baf0, osslcb=0x7ffff7779313 <ossl_callback_to_pkey_gencb>, cbarg=0x5723c0) at providers/implementations/keymgmt/dsa_kmgmt.c:630
#1  0x00007ffff776cd16 in evp_keymgmt_gen (keymgmt=0x586a40, genctx=0x58baf0, cb=0x7ffff7779313 <ossl_callback_to_pkey_gencb>, cbarg=0x5723c0) at crypto/evp/keymgmt_meth.c:466
#2  0x00007ffff776b5ff in evp_keymgmt_util_gen (target=0x5a8090, keymgmt=0x586a40, genctx=0x58baf0, cb=0x7ffff7779313 <ossl_callback_to_pkey_gencb>, cbarg=0x5723c0) at crypto/evp/keymgmt_lib.c:519
#3  0x00007ffff7779594 in EVP_PKEY_generate (ctx=0x5723c0, ppkey=0x7fffffffd548) at crypto/evp/pmeth_gn.c:163
#4  0x00007ffff7779705 in EVP_PKEY_paramgen (ctx=0x5723c0, ppkey=0x7fffffffd548) at crypto/evp/pmeth_gn.c:206
#5  0x000000000048d9fa in app_paramgen (ctx=0x5723c0, alg=0x7fffffffdd4a "DSA") at apps/lib/apps.c:3675
#6  0x000000000043077a in genpkey_main (argc=8, argv=0x7fffffffd8d0) at apps/genpkey.c:275
#7  0x000000000043d794 in do_cmd (prog=0x5386d0, argc=8, argv=0x7fffffffd8d0) at apps/openssl.c:525
#8  0x000000000043d341 in main (argc=8, argv=0x7fffffffd8d0) at apps/openssl.c:368
```

## Testing with Ruby

This section is for people working for Ruby. People at OpenSSL project don't have to check this section.

### My Ruby testing environment.

```
$ which ruby
~/.local/ruby-4.1.0dev-debug-dcfbbdc38c-openssl-4.0.0-dev-1cb0d36b39/bin/ruby

$ ruby -v
ruby 4.1.0dev (2026-01-08T09:48:38Z master dcfbbdc38c) +PRISM [x86_64-linux]

$ pwd
/home/jaruga/git/ruby/openssl

$ ldd lib/openssl.so
	linux-vdso.so.1 (0x00007f4edc946000)
	libruby.so.4.1 => /home/jaruga/.local/ruby-4.1.0dev-debug-dcfbbdc38c-openssl-4.0.0-dev-1cb0d36b39/lib/libruby.so.4.1 (0x00007f4edbe00000)
	libssl.so.4 => /home/jaruga/.local/openssl-4.1.0-dev-fips-debug-50724a9686-wip/lib/libssl.so.4 (0x00007f4edc74c000)
	libcrypto.so.4 => /home/jaruga/.local/openssl-4.1.0-dev-fips-debug-50724a9686-wip/lib/libcrypto.so.4 (0x00007f4edb600000)
	libm.so.6 => /lib64/libm.so.6 (0x00007f4edbd0b000)
	libc.so.6 => /lib64/libc.so.6 (0x00007f4edb40d000)
	libz.so.1 => /lib64/libz.so.1 (0x00007f4edc70c000)
	libcrypt.so.2 => /lib64/libcrypt.so.2 (0x00007f4edc6d7000)
	libgcc_s.so.1 => /lib64/libgcc_s.so.1 (0x00007f4edbcdf000)
	/lib64/ld-linux-x86-64.so.2 (0x00007f4edc948000)
```

### Test with Ruby scripts

Also tested the testing matrix, (DH, DSA) x (non-FIPS, FIPS) = 4 cases.

non-FIPS

```
$ ruby -I ./lib ~/git/report-openssl-improve-ffc-params-error-messages/dh.rb
/home/jaruga/git/report-openssl-improve-ffc-params-error-messages/dh.rb:4: warning: error on stack: error:0280007F:Diffie-Hellman routines:ffc_validate_LN:bad ffc parameters ((L, N)=(512, 160) should be (1024, 160), (2048, 224) or (2048, 256))
/home/jaruga/git/report-openssl-improve-ffc-params-error-messages/dh.rb:4:in 'OpenSSL::PKey.generate_parameters': EVP_PKEY_paramgen: bad ffc parameters ((L, N)=(512, 160) should be (1024, 160), (2048, 224) or (2048, 256)) (OpenSSL::PKey::PKeyError)
OpenSSL error queue reported 1 errors:
error:0280007F:Diffie-Hellman routines:ffc_validate_LN:bad ffc parameters ((L, N)=(512, 160) should be (1024, 160), (2048, 224) or (2048, 256))
	from /home/jaruga/git/report-openssl-improve-ffc-params-error-messages/dh.rb:4:in '<main>'

$ ruby -I ./lib ~/git/report-openssl-improve-ffc-params-error-messages/dsa.rb
/home/jaruga/var/git/ruby/openssl/lib/openssl/pkey.rb:211: warning: error on stack: error:05000072:dsa routines:ffc_validate_LN:bad ffc parameters ((L, N)=(512, 160) should be at least (1024, 160))
/home/jaruga/var/git/ruby/openssl/lib/openssl/pkey.rb:211:in 'OpenSSL::PKey.generate_key': EVP_PKEY_keygen: bad ffc parameters ((L, N)=(512, 160) should be at least (1024, 160)) (OpenSSL::PKey::PKeyError)
OpenSSL error queue reported 1 errors:
error:05000072:dsa routines:ffc_validate_LN:bad ffc parameters ((L, N)=(512, 160) should be at least (1024, 160))
	from /home/jaruga/var/git/ruby/openssl/lib/openssl/pkey.rb:211:in 'OpenSSL::PKey::DSA.generate'
	from /home/jaruga/var/git/ruby/openssl/lib/openssl/pkey.rb:218:in 'OpenSSL::PKey::DSA.new'
	from /home/jaruga/git/report-openssl-improve-ffc-params-error-messages/dsa.rb:4:in '<main>'
```

FIPS

I couldn't test DSA FIPS case. See the Notes section for details.

```
$ OPENSSL_CONF=$OPENSSL_DIR/ssl/openssl_fips.cnf \
  ruby -I ./lib ~/git/report-openssl-improve-ffc-params-error-messages/dh_fips.rb
/home/jaruga/git/report-openssl-improve-ffc-params-error-messages/dh_fips.rb:5: warning: error on stack: error:0280007F:Diffie-Hellman routines:ffc_validate_LN:bad ffc parameters ((L, N)=(512, 160) should be (2048, 224) or (2048, 256))
/home/jaruga/git/report-openssl-improve-ffc-params-error-messages/dh_fips.rb:5:in 'OpenSSL::PKey.generate_parameters': EVP_PKEY_paramgen: bad ffc parameters ((L, N)=(512, 160) should be (2048, 224) or (2048, 256)) (OpenSSL::PKey::PKeyError)
OpenSSL error queue reported 1 errors:
error:0280007F:Diffie-Hellman routines:ffc_validate_LN:bad ffc parameters ((L, N)=(512, 160) should be (2048, 224) or (2048, 256))
	from /home/jaruga/git/report-openssl-improve-ffc-params-error-messages/dh_fips.rb:5:in '<main>'

$ OPENSSL_CONF=$OPENSSL_DIR/ssl/openssl_fips.cnf \
  ruby -I ./lib ~/git/report-openssl-improve-ffc-params-error-messages/dsa_fips.rb
/home/jaruga/git/report-openssl-improve-ffc-params-error-messages/dsa_fips.rb:6: warning: error on stack: error:030000E9:digital envelope routines:evp_keymgmt_gen:provider keymgmt failure (DSA key generation:OpenSSL DSA implementation)
/home/jaruga/git/report-openssl-improve-ffc-params-error-messages/dsa_fips.rb:6:in 'OpenSSL::PKey.generate_parameters': EVP_PKEY_paramgen: provider keymgmt failure (DSA key generation:OpenSSL DSA implementation) (OpenSSL::PKey::PKeyError)
OpenSSL error queue reported 1 errors:
error:030000E9:digital envelope routines:evp_keymgmt_gen:provider keymgmt failure (DSA key generation:OpenSSL DSA implementation)
	from /home/jaruga/git/report-openssl-improve-ffc-params-error-messages/dsa_fips.rb:6:in '<main>'
```

### Notes

#### Couldn't confirm the changed error message in the DSA FIPS case

I couldn't test the DSA FIPS case, to print the changed FFC parameters error message.
Because the case was rejected by
[this DSA sign disabled error](https://github.com/openssl/openssl/blob/e1eb88118a95445eb9c2d074c853776feaab4de7/providers/implementations/keymgmt/dsa_kmgmt.c#L627-L630)
which is the same part from the above openssl test in DSA FIPS case.

The debug log is below.

```
$ gdb --args ruby -I ./lib ~/git/report-openssl-improve-ffc-params-error-messages/dsa_fips.rb
...
(gdb) set environment OPENSSL_CONF=/home/jaruga/.local/openssl-4.1.0-dev-fips-debug-50724a9686-wip/ssl/openssl_fips.cnf
(gdb) b dsa_gen
...
(gdb) n
627	    if (!OSSL_FIPS_IND_ON_UNAPPROVED(gctx, OSSL_FIPS_IND_SETTABLE0,
(gdb) n
630	        return 0;
(gdb) f
#0  dsa_gen (genctx=0x5ce390, osslcb=0x7fffcd779313 <ossl_callback_to_pkey_gencb>, cbarg=0x75eee0) at providers/implementations/keymgmt/dsa_kmgmt.c:630
630	        return 0;
(gdb) bt
#0  dsa_gen (genctx=0x5ce390, osslcb=0x7fffcd779313 <ossl_callback_to_pkey_gencb>, cbarg=0x75eee0) at providers/implementations/keymgmt/dsa_kmgmt.c:630
#1  0x00007fffcd76cd16 in evp_keymgmt_gen (keymgmt=0x5a8060, genctx=0x5ce390, cb=0x7fffcd779313 <ossl_callback_to_pkey_gencb>, cbarg=0x75eee0) at crypto/evp/keymgmt_meth.c:466
#2  0x00007fffcd76b5ff in evp_keymgmt_util_gen (target=0x57ad30, keymgmt=0x5a8060, genctx=0x5ce390, cb=0x7fffcd779313 <ossl_callback_to_pkey_gencb>, cbarg=0x75eee0) at crypto/evp/keymgmt_lib.c:519
#3  0x00007fffcd779594 in EVP_PKEY_generate (ctx=0x75eee0, ppkey=0x7fffffffc198) at crypto/evp/pmeth_gn.c:163
#4  0x00007fffcd779705 in EVP_PKEY_paramgen (ctx=0x75eee0, ppkey=0x7fffffffc198) at crypto/evp/pmeth_gn.c:206
#5  0x00007fffce0355bb in pkey_blocking_gen (ptr=0x7fffffffc190) at ../../../../ext/openssl/ossl_pkey.c:358
#6  0x00007ffff78d110b in rb_nogvl (func=0x7fffce03557e <pkey_blocking_gen>, data1=0x7fffffffc190, ubf=0x7fffce03555d <pkey_blocking_gen_stop>, data2=0x7fffffffc190, flags=0) at thread.c:1628
#7  0x00007ffff78d11f1 in rb_thread_call_without_gvl (func=0x7fffce03557e <pkey_blocking_gen>, data1=0x7fffffffc190, ubf=0x7fffce03555d <pkey_blocking_gen_stop>, data2=0x7fffffffc190) at thread.c:1741
#8  0x00007fffce0358a5 in pkey_generate (argc=2, argv=0x7fffe92ff048, self=140736647918400, genparam=1) at ../../../../ext/openssl/ossl_pkey.c:434
#9  0x00007fffce035938 in ossl_pkey_s_generate_parameters (argc=2, argv=0x7fffe92ff048, self=140736647918400) at ../../../../ext/openssl/ossl_pkey.c:473
#10 0x00007ffff791db1d in ractor_safe_call_cfunc_m1 (recv=140736647918400, argc=2, argv=0x7fffe92ff048, func=0x7fffce03590e <ossl_pkey_s_generate_parameters>) at vm_insnhelper.c:3711
#11 0x00007ffff791e773 in vm_call_cfunc_with_frame_ (ec=0x40cbd0, reg_cfp=0x7fffe93fefa0, calling=0x7fffffffc650, argc=2, argv=0x7fffe92ff048, stack_bottom=0x7fffe92ff040) at vm_insnhelper.c:3902
#12 0x00007ffff791ea3b in vm_call_cfunc_with_frame (ec=0x40cbd0, reg_cfp=0x7fffe93fefa0, calling=0x7fffffffc650) at vm_insnhelper.c:3948
#13 0x00007ffff791eb64 in vm_call_cfunc_other (ec=0x40cbd0, reg_cfp=0x7fffe93fefa0, calling=0x7fffffffc650) at vm_insnhelper.c:3974
#14 0x00007ffff791efa0 in vm_call_cfunc (ec=0x40cbd0, reg_cfp=0x7fffe93fefa0, calling=0x7fffffffc650) at vm_insnhelper.c:4056
#15 0x00007ffff7921c4d in vm_call_method_each_type (ec=0x40cbd0, cfp=0x7fffe93fefa0, calling=0x7fffffffc650) at vm_insnhelper.c:4888
#16 0x00007ffff7922716 in vm_call_method (ec=0x40cbd0, cfp=0x7fffe93fefa0, calling=0x7fffffffc650) at vm_insnhelper.c:5014
#17 0x00007ffff7922914 in vm_call_general (ec=0x40cbd0, reg_cfp=0x7fffe93fefa0, calling=0x7fffffffc650) at vm_insnhelper.c:5058
#18 0x00007ffff792531c in vm_sendish (ec=0x40cbd0, reg_cfp=0x7fffe93fefa0, cd=0x73aa80, block_handler=0, method_explorer=mexp_search_method) at vm_insnhelper.c:6124
#19 0x00007ffff792d5c3 in vm_exec_core (ec=0x40cbd0) at insns.def:904
#20 0x00007ffff7947575 in rb_vm_exec (ec=0x40cbd0) at vm.c:2798
#21 0x00007ffff7948456 in rb_iseq_eval_main (iseq=0x7fffce09ffa8) at vm.c:3064
#22 0x00007ffff77023ff in rb_ec_exec_node (ec=0x40cbd0, n=0x7fffce09ffa8) at eval.c:283
#23 0x00007ffff7702567 in ruby_run_node (n=0x7fffce09ffa8) at eval.c:321
#24 0x0000000000400519 in rb_main (argc=4, argv=0x7fffffffd858) at ./main.c:42
#25 0x0000000000400576 in main (argc=4, argv=0x7fffffffd858) at ./main.c:62
```
