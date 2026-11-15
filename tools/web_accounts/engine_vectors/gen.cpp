// Prints the engine's own SRP verifier (hex) for a name, a password and a salt
// (hex), using reference_projects/luanti/src/util/srp.cpp unchanged; the name is
// lowered as util/auth.cpp gen_srp_v does. Built by build.sh beside this file.
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include "srp.h"
namespace porting { bool secure_rand_fill_buf(void *, size_t) { return false; } }
static std::string lower(const std::string &s){ std::string r=s; for(auto &c:r) if(c>='A'&&c<='Z') c+=32; return r; }
int main(int argc, char **argv) {
	std::string name = argv[1], pw = argv[2], salthex = argv[3];
	size_t len_s = salthex.size()/2;
	unsigned char *s = (unsigned char*)malloc(len_s);
	for (size_t i=0;i<len_s;i++) sscanf(salthex.c_str()+2*i, "%2hhx", &s[i]);
	unsigned char *v = NULL; size_t len_v = 0;
	std::string n = lower(name); // as util/auth.cpp gen_srp_v
	if (srp_create_salted_verification_key(SRP_SHA256, SRP_NG_2048, n.c_str(),
			(const unsigned char*)pw.data(), pw.size(), &s, &len_s, &v, &len_v, NULL, NULL) != SRP_OK) return 1;
	for (size_t i=0;i<len_v;i++) printf("%02x", v[i]);
	printf("\n");
	return 0;
}
