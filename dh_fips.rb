require 'openssl'

OpenSSL.debug = true
OpenSSL.fips_mode = true
OpenSSL::PKey.generate_parameters("DHX", {
  "pbits" => 512,
  "qbits" => 160,
  "dh_paramgen_type" => "2"
})
