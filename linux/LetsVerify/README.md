SSL/TLS Certificates
X.509 is an ITU standard defining the format of public key certificates. X.509 are used in TLS/SSL, which is the basis for HTTPS. An X.509 certificate binds an identity to a public key using a digital signature. A certificate contains an identity (hostname, organization, etc.) and a public key (RSA, DSA, ECDSA, ed25519, etc.), and is either signed by a Certificate Authority or is Self-Signed.

Self-Signed Certificates
Generate CA
Generate RSA
openssl genrsa -aes256 -out ca-key.pem 4096
Generate a public CA Cert
openssl req -new -x509 -sha256 -days 365 -key ca-key.pem -out ca.pem
Optional Stage: View Certificate's Content
openssl x509 -in ca.pem -text
openssl x509 -in ca.pem -purpose -noout -text
Generate Certificate
Create a RSA key
openssl genrsa -out cert-key.pem 4096
Create a Certificate Signing Request (CSR)
openssl req -new -sha256 -subj "/CN=yourcn" -key cert-key.pem -out cert.csr
Create a extfile with all the alternative names
echo "subjectAltName=DNS:your-dns.record,IP:257.10.10.1" >> extfile.cnf
# optional
echo extendedKeyUsage = serverAuth >> extfile.cnf
Create the certificate
openssl x509 -req -sha256 -days 365 -in cert.csr -CA ca.pem -CAkey ca-key.pem -out cert.pem -extfile extfile.cnf -CAcreateserial
