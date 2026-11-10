"""Convert the existing local PEM identity to the PKCS12 format Dart requires on iOS.

Run with Python + cryptography. This does not print any credential contents.
The result is still a private development credential, not a public-release asset.
"""
from pathlib import Path
from cryptography import x509
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.serialization import pkcs12

certs = Path(__file__).resolve().parents[1] / 'assets/certs'
key = serialization.load_pem_private_key((certs / 'ecos.key').read_bytes(), password=None)
cert = x509.load_pem_x509_certificate((certs / 'ecos.crt').read_bytes())
root = x509.load_pem_x509_certificate((certs / 'ola_diag_root.crt').read_bytes())
result = pkcs12.serialize_key_and_certificates(b'openola-local', key, cert, [root], serialization.NoEncryption())
(certs / 'ecos-ios.p12').write_bytes(result)
loaded_key, loaded_cert, _ = pkcs12.load_key_and_certificates(result, None)
assert loaded_cert.public_bytes(serialization.Encoding.DER) == cert.public_bytes(serialization.Encoding.DER)
assert loaded_key.public_key().public_bytes(serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo) == key.public_key().public_bytes(serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo)
print('iOS PKCS12 identity generated and public-key/certificate equivalence verified.')
