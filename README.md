# `test-ca-files`

A CA and certs for testing PEM loading and other suchlikes.

## Prerequisites

* [`gomplate`](https://docs.gomplate.ca/installing/)
* [`openssl`](https://www.openssl.org)
* [`util-linux`](https://github.com/util-linux/util-linux) (not to worry -- available on macOS via `brew`) 
 
## Usage

```bash
make
```

This will create all missing keys, csrs, and certs.

```bash
make clean
```

This will remove them all.

## Caveat Emptor

This project was not created for security but rather to test other
projects with real and diverse certs and keys.  Please do not use it
to create a CA.

If you are in need of a CA, try [`easy-rsa`]() from OpenVPN instead.

## License

See [LICENSE](./LICENSE)
