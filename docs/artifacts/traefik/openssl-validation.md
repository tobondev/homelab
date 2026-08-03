# OpenSSL Validation Artifact

## Cockpit - No Traefik (Self-Signed HTTPS)

```
CONNECTED(00000003)
---
Certificate chain
 0 s:O={ASN.1 Syntax}, CN={MAIN_SERVER}
 i:O={ASN.1 Syntax}, CN={MAIN_SERVER}
   a:PKEY: RSA, 2048 (bit); sigalg: sha256WithRSAEncryption
   v:NotBefore: Feb 24 17:36:53 2026 GMT; NotAfter: Mar 26 17:36:53 2027 GMT
---
Server certificate
subject=O={ASN.1 Syntax}, CN={MAIN_SERVER}
issuer=O={ASN.1 Syntax}, CN={MAIN_SERVER}
---
No client certificate CA names sent
Peer signing digest: SHA256
Peer signature type: rsa_pss_rsae_sha256
Peer Temp Key: X25519, 253 bits
---
SSL handshake has read 1494 bytes and written 1639 bytes
Verification error: self-signed certificate
---
New, TLSv1.3, Cipher is TLS_AES_256_GCM_SHA384
Protocol: TLSv1.3
Server public key is 2048 bit
This TLS version forbids renegotiation.
Compression: NONE
Expansion: NONE
No ALPN negotiated
Early data was not sent
Verify return code: 18 (self-signed certificate)
---
```

## Cockpit - Traefik - Wildcard DNS-01 Certificate.

```
CONNECTED(00000003)
---
Certificate chain
 0 s:CN={DOMAIN_NAME}
   i:C=US, O=Let's Encrypt, CN=YR1
   a:PKEY: RSA, 4096 (bit); sigalg: sha256WithRSAEncryption
   v:NotBefore: Aug  2 18:10:15 2026 GMT; NotAfter: Oct 31 18:10:14 2026 GMT
---
Server certificate
subject=CN={DOMAIN_NAME}
issuer=C=US, O=Let's Encrypt, CN=YR1
---
No client certificate CA names sent
Peer signing digest: SHA256
Peer signature type: rsa_pss_rsae_sha256
Negotiated TLS1.3 group: X25519MLKEM768
---
SSL handshake has read 6224 bytes and written 1628 bytes
Verification: OK
---
New, TLSv1.3, Cipher is TLS_AES_128_GCM_SHA256
Protocol: TLSv1.3
Server public key is 4096 bit
This TLS version forbids renegotiation.
Compression: NONE
Expansion: NONE
No ALPN negotiated
Early data was not sent
Verify return code: 0 (ok)
---
```

## IT-Tools - No Traefik

```
CONNECTED(00000003)
---
no peer certificate available
---
No client certificate CA names sent
Negotiated TLS1.3 group: <NULL>
---
SSL handshake has read 5 bytes and written 1533 bytes
Verification: OK
---
New, (NONE), Cipher is (NONE)
Protocol: TLSv1.3
This TLS version forbids renegotiation.
Compression: NONE
Expansion: NONE
No ALPN negotiated
Early data was not sent
Verify return code: 0 (ok)
---
```

## IT-Tools - Traefik

```
CONNECTED(00000003)
---
Server certificate
subject=CN={DOMAIN_NAME}
issuer=C=US, O=Let's Encrypt, CN=YR1
---
No client certificate CA names sent
Peer signing digest: SHA256
Peer signature type: rsa_pss_rsae_sha256
Negotiated TLS1.3 group: X25519MLKEM768
---
SSL handshake has read 6224 bytes and written 1628 bytes
Verification: OK
---
New, TLSv1.3, Cipher is TLS_AES_128_GCM_SHA256
Protocol: TLSv1.3
Server public key is 4096 bit
This TLS version forbids renegotiation.
Compression: NONE
Expansion: NONE
No ALPN negotiated
Early data was not sent
Verify return code: 0 (ok)
---
```
