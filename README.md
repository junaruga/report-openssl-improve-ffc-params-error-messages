# report-openssl-improve-ffc-params-error-messages

This repository is to manage the files related to
[this openssl ticket](https://github.com/openssl/openssl/issues/17108).

## My testing environment.

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

Ruby (ruby/ruby)

```
$ which ruby
~/.local/ruby-4.1.0dev-debug-dcfbbdc38c-openssl-4.0.0-dev-1cb0d36b39/bin/ruby

$ ruby -v
ruby 4.1.0dev (2026-01-08T09:48:38Z master dcfbbdc38c) +PRISM [x86_64-linux]
```

Ruby OpenSSL (ruby/openssl)

```
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

## Test with Ruby scripts

Tested the testing matrix, (DH, DSA) x (FIPS, non-FIPS) = 4 cases.

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
