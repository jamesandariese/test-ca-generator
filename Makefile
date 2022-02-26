.PHONY: all always-build

# SECONDEXPANSION is weird.  Let's do it this way instead.
early-all: all

RELPATH := $(shell realpath .)

version.txt: version.txt.tmpl always-build
	gomplate < version.txt.tmpl > version.txt
	git add version.txt

prepare-release: version.txt

CA_TARGETS =
TARGETS = 
RSA_CERT_TARGETS =
EC_CERT_TARGETS =

TEST_TARGETS =

CA_TARGETS += ca/ca.pub
ca/ca.pub: ca/ca.key | ca
	flock "$@" openssl rsa -pubout < "$<" > "$@"

CA_TARGETS += ca/ca.key
ca/ca.key: | ca
	flock "$@" openssl genrsa 512 > "$@"

CA_TARGETS += ca/ca.crt
ca/ca.crt: ca/ca.key
	flock "$@" openssl req -x509 -new -key "$<" -subj "/C=US/CN=testca" -nodes -out "$@"

CA_TARGETS += ca/ca.db.index
ca/ca.db.index:
	flock "$@" true >> "$@"

CA_TARGETS += ca ca/certs
ca ca/certs:
	mkdir -p ca/certs

%.csr: %.key
	flock "$@" openssl req -new \
							-subj "/C=US/CN=$<" \
              -addext "subjectAltName = DNS:foo.co.uk" \
              -addext "certificatePolicies = 1.2.3.4" \
							-nodes \
              -key "$<" -out "$@"

%.crt: %.csr $(CA_TARGETS)
	flock ca/ca.crt openssl ca -batch -config ca.conf -out "$@" -infiles "$<"

define genec
EC_CERT_TARGETS += ec_$(1).crt
TARGETS += ec_$(1).key ec_$(1).csr
ec_$(1).csr: ec_$(1).key
ec_$(1).crt: ec_$(1).csr
ec_$(1).key:
	flock "$$@" openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:"$(1)" -pkeyopt ec_param_enc:named_curve -out "$$@"
endef


define genrsa
RSA_CERT_TARGETS += rsa_$(1).crt
TARGETS += rsa_$(1).key rsa_$(1).csr
rsa_$(1).csr: rsa_$(1).key
rsa_$(1).crt: rsa_$(1).csr
rsa_$(1).key:
	flock "$$@" openssl genrsa $(1) > "$$@"
endef

$(eval $(call genec,P-256))
$(eval $(call genec,P-521))
$(eval $(call genec,P-384))
$(eval $(call genrsa,512))
$(eval $(call genrsa,1024))
$(eval $(call genrsa,2048))
$(eval $(call genrsa,3072))
$(eval $(call genrsa,4096))
$(eval $(call genrsa,8192))
#$(eval $(call genrsa,16384))

TEST_TARGETS += test-certs-match-keys
test-certs-match-keys: $(EC_CERT_TARGETS) $(RSA_CERT_TARGETS)
	: ;\
	for f in $^;do \
		CRT="$$f" ;\
  	KEY="$${f%.crt}.key" ;\
		CRTPUB="$$(openssl x509 -noout -pubkey -in $${CRT})" ;\
		CRT_SUBCOMMAND="$${CRT%%_*}" ;\
		KEYPUB="$$(openssl $${CRT_SUBCOMMAND} -in $${KEY} -pubout 2>/dev/null)" ;\
		if [ "$$CRTPUB" != "$$KEYPUB" ];then\
			echo "$${CRT}'s public key oodoes not match $${KEY}'s public key" ; \
			echo crtpub ;\
			echo "$$CRTPUB" ;\
			echo keypub ;\
			echo "$$KEYPUB" ;\
			exit 1 ;\
		else \
			echo "$$CRT and $$KEY match" ;\
		fi ;\
	done

TEST_TARGETS += test-verify
test-verify: ca/ca.crt $(RSA_CERT_TARGETS) $(EC_CERT_TARGETS)
	openssl verify -CAfile "$<" $^

test: $(TEST_TARGETS)
	echo "Add tests" 1>&2
	false

ALL_REAL_TARGETS = $(CA_TARGETS) $(EC_CERT_TARGETS) $(RSA_CERT_TARGETS) $(TARGETS)
all: version.txt $(ALL_REAL_TARGETS) $(TEST_TARGETS)
clean:
	rm -rf $(ALL_REAL_TARGETS)
always-build:

