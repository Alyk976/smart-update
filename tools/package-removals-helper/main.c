#include <alpm.h>

#include <stdio.h>
#include <stdlib.h>

#define ALPM_ROOT "/"
#define ALPM_DBPATH "/var/lib/pacman/"

int main(void)
{
    alpm_errno_t error = ALPM_ERR_OK;
    alpm_handle_t *handle = alpm_initialize(ALPM_ROOT, ALPM_DBPATH, &error);

    if (handle == NULL) {
        fprintf(
            stderr,
            "package-removals-helper: alpm_initialize failed: %s\n",
            alpm_strerror(error)
        );
        return EXIT_FAILURE;
    }

    alpm_db_t *local_db = alpm_get_localdb(handle);

    if (local_db == NULL) {
        fprintf(stderr, "package-removals-helper: local database unavailable\n");

        if (alpm_release(handle) != 0) {
            fprintf(stderr, "package-removals-helper: alpm_release failed\n");
        }

        return EXIT_FAILURE;
    }

    const alpm_list_t *package_cache = alpm_db_get_pkgcache(local_db);
    const size_t package_count = alpm_list_count(package_cache);

    printf("%zu\n", package_count);

    if (alpm_release(handle) != 0) {
        fprintf(stderr, "package-removals-helper: alpm_release failed\n");
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}
