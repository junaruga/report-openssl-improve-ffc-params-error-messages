require 'openssl'

OpenSSL.debug = true
OpenSSL.fips_mode = true

OpenSSL::PKey.generate_parameters("DSA", {
  "pbits" => 2048,
  "qbits" => 220
})
