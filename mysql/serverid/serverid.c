#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

unsigned int string2int(char *s)
{
    int i;
    char *n, *p;
    unsigned int r = 0;

    for (i = 4, n = strtok_r(s, ".", &p); i > 0 && n; i--, n = strtok_r(NULL, ".", &p)) {
        r += atoi(n) << (8 * (i - 1));
    }

    return r;
}

void int2string(unsigned int addr, char *s)
{
    int i;
    unsigned int n;
    unsigned char r[4];

    for (i = 4; i > 0; i--) {
        n = addr;
        r[i - 1] = (unsigned char)((n >> (8 * (i - 1))) & 0xff);
    }
    sprintf(s, "%u.%u.%u.%u", r[3], r[2], r[1], r[0]);
}

int main(int argc, char *argv[])
{
    int ch, r = 0;
    char s[16];

    while ((ch = getopt(argc, argv, "r")) != -1) {
        switch (ch) {
        case 'r':
            r = 1;
            break;
        }
    }
    argc -= optind;
    argv += optind;

    if (r) {
        int2string((unsigned int)atoi(*argv), s);
        printf("%s\n", s);
    }
    else {
        printf("%u\n", string2int(*argv));
    }

    exit(EXIT_SUCCESS);
}
