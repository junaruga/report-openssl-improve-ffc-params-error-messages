require 'openssl'

OpenSSL.debug = true
OpenSSL::PKey::DSA.new(512)
