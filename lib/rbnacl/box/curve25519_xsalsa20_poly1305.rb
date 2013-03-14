# encoding: binary
module Crypto
  class Box

    # The Curve25519XSalsa20Poly1305 class boxes and opens messages between a pair of keys
    #
    # This class uses the given public and secret keys to derive a shared key,
    # which is used with the nonce given to encrypt the given messages and
    # decrypt the given ciphertexts.  The same shared key will generated from
    # both pairing of keys, so given two keypairs belonging to alice (pkalice,
    # skalice) and bob(pkbob, skbob), the key derived from (pkalice, skbob) with
    # equal that from (pkbob, skalice).  This is how the system works:
    #
    #
    # It is VITALLY important that the nonce is a nonce, i.e. it is a number used
    # only once for any given pair of keys.  If you fail to do this, you
    # compromise the privacy of the the messages encrypted.  Also, bear in mind
    # the property mentioned just above. Give your nonces a different prefix, or
    # have one side use an odd counter and one an even counter.  Just make sure
    # they are different.
    #
    # The ciphertexts generated by this class include a 16-byte authenticator which
    # is checked as part of the decryption.  An invalid authenticator will cause
    # the unbox function to raise.  The authenticator is not a signature.  Once
    # you've looked in the box, you've demonstrated the ability to create
    # arbitrary valid messages, so messages you send are repudiatable.  For
    # non-repudiatable messages, sign them before or after encryption.
    #
    # * Shared key derivation: Curve25519, a fast elliptic curve curve
    # * Encryption: XSalsa20, a fast stream cipher primitive
    # * Authentication: Poly1305, a fast one time authentication primitive
    #
    # **WARNING**: This class provides direct access to a low-level
    # cryptographic method.  You should not use this class without good reason
    # and instead use the Crypto::Box box class which will always point
    # to the best primitive the library provides bindings for.  It also
    # provides a nicer interface, with e.g. decoding of ascii-encoded keys.
    class Curve25519XSalsa20Poly1305
      # Number of bytes for a nonce
      NONCEBYTES = NaCl::CURVE25519_XSALSA20_POLY1305_BOX_NONCEBYTES

      # Number of bytes for the shared key
      BEFORENMBYTES = NaCl::CURVE25519_XSALSA20_POLY1305_BOX_BEFORENMBYTES

      # Create a new Curve25519XSalsa20Poly1305 box
      #
      # Sets up the Curve25519XSalsa20Poly1305 box for deriving the shared key and
      # encrypting and decrypting messages.
      #
      # @param public_key [String,Crypto::PublicKey] The public key to encrypt to
      # @param private_key [String,Crypto::PrivateKey] The private key to encrypt with
      #
      # @raise [Crypto::LengthError] on invalid keys
      #
      # @return [Crypto::Box] The new Curve25519XSalsa20Poly1305 box, ready to use
      def initialize(public_key, private_key)
        @public_key  = public_key.to_s if public_key
        @private_key = private_key.to_s if private_key
        Util.check_length(@public_key,  PublicKey::BYTES,  "Public key")
        Util.check_length(@private_key, PrivateKey::BYTES, "Private key")
      end

      # Returns the primitive name
      #
      # @return [Symbol] the primitive name
      def self.primitive
        :curve25519_xsalsa20_poly1305
      end

      # Returns the primitive name
      #
      # @return [Symbol] the primitive name
      def primitive
        self.class.primitive
      end

      # returns the number of bytes in a nonce
      #
      # @return [Integer] Number of nonce bytes
      def nonce_bytes
        NONCEBYTES
      end

      # Encrypts a message
      #
      # Encrypts the message with the given nonce to the keypair set up when
      # initializing the class.  Make sure the nonce is unique for any given
      # keypair, or you might as well just send plain text.
      #
      # This function takes care of the padding required by the NaCL C API.
      #
      # @param nonce [String] A 24-byte string containing the nonce.
      # @param message [String] The message to be encrypted.
      #
      # @raise [Crypto::LengthError] If the nonce is not valid
      #
      # @return [String] The ciphertext without the nonce prepended (BINARY encoded)
      def box(nonce, message)
        Util.check_length(nonce, NONCEBYTES, "Nonce")
        msg = Util.prepend_zeros(NaCl::ZEROBYTES, message)
        ct  = Util.zeros(msg.bytesize)

        NaCl.crypto_box_curve25519_xsalsa20_poly1305_afternm(ct, msg, msg.bytesize, nonce, beforenm) || raise(CryptoError, "Encryption failed")
        Util.remove_zeros(NaCl::BOXZEROBYTES, ct)
      end
      alias encrypt box

      # Decrypts a ciphertext
      #
      # Decrypts the ciphertext with the given nonce using the keypair setup when
      # initializing the class.
      #
      # This function takes care of the padding required by the NaCL C API.
      #
      # @param nonce [String] A 24-byte string containing the nonce.
      # @param ciphertext [String] The message to be decrypted.
      #
      # @raise [Crypto::LengthError] If the nonce is not valid
      # @raise [Crypto::CryptoError] If the ciphertext cannot be authenticated.
      #
      # @return [String] The decrypted message (BINARY encoded)
      def open(nonce, ciphertext)
        Util.check_length(nonce, NONCEBYTES, "Nonce")
        ct = Util.prepend_zeros(NaCl::BOXZEROBYTES, ciphertext)
        message  = Util.zeros(ct.bytesize)

        NaCl.crypto_box_curve25519_xsalsa20_poly1305_open_afternm(message, ct, ct.bytesize, nonce, beforenm) || raise(CryptoError, "Decryption failed. Ciphertext failed verification.")
        Util.remove_zeros(NaCl::ZEROBYTES, message)
      end
      alias decrypt open

      private
      def beforenm
        @k ||= begin
                 k = Util.zeros(BEFORENMBYTES)
                 NaCl.crypto_box_curve25519_xsalsa20_poly1305_beforenm(k, @public_key, @private_key) || raise(CryptoError, "Failed to derive shared key")
                 k
               end
      end
    end
  end
end
