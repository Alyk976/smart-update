#define _POSIX_C_SOURCE 200809L

#include <alpm.h>

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>

#define ALPM_ROOT "/"
#define ALPM_DBPATH "/var/lib/pacman/"
#define REPOSITORY_NAME_MAX 128

static int repository_name_is_valid(const char *name)
{
    if (name == NULL || *name == '\0') {
        return 0;
    }

    for (const unsigned char *character = (const unsigned char *)name;
         *character != '\0';
         character++) {
        if (!isalnum(*character)
            && *character != '-'
            && *character != '_'
            && *character != '.') {
            return 0;
        }
    }

    return 1;
}

static int register_sync_databases(alpm_handle_t *handle)
{
    FILE *stream = popen("pacman-conf --repo-list", "r");

    if (stream == NULL) {
        fprintf(stderr, "package-removals-helper: cannot run pacman-conf\n");
        return -1;
    }

    char repository[REPOSITORY_NAME_MAX];
    size_t repository_count = 0;

    while (fgets(repository, sizeof(repository), stream) != NULL) {
        repository[strcspn(repository, "\r\n")] = '\0';

        if (!repository_name_is_valid(repository)) {
            fprintf(
                stderr,
                "package-removals-helper: invalid repository name: %s\n",
                repository
            );
            (void)pclose(stream);
            return -1;
        }

        if (alpm_register_syncdb(
                handle,
                repository,
                ALPM_SIG_USE_DEFAULT
            ) == NULL) {
            fprintf(
                stderr,
                "package-removals-helper: cannot register repository %s: %s\n",
                repository,
                alpm_strerror(alpm_errno(handle))
            );
            (void)pclose(stream);
            return -1;
        }

        repository_count++;
    }

    const int command_status = pclose(stream);

    if (command_status == -1
        || !WIFEXITED(command_status)
        || WEXITSTATUS(command_status) != 0) {
        fprintf(stderr, "package-removals-helper: pacman-conf failed\n");
        return -1;
    }

    if (repository_count == 0) {
        fprintf(stderr, "package-removals-helper: no repository configured\n");
        return -1;
    }

    return 0;
}

static void answer_question(void *context, alpm_question_t *question)
{
    (void)context;

    switch (question->type) {
        case ALPM_QUESTION_REPLACE_PKG:
            question->replace.replace = 1;
            break;
        case ALPM_QUESTION_CONFLICT_PKG:
            question->conflict.remove = 1;
            break;
        case ALPM_QUESTION_SELECT_PROVIDER:
            question->select_provider.use_index = 0;
            break;
        case ALPM_QUESTION_INSTALL_IGNOREPKG:
            question->install_ignorepkg.install = 0;
            break;
        case ALPM_QUESTION_REMOVE_PKGS:
            question->remove_pkgs.skip = 0;
            break;
        case ALPM_QUESTION_CORRUPTED_PKG:
            question->corrupted.remove = 0;
            break;
        case ALPM_QUESTION_IMPORT_KEY:
            question->import_key.import = 0;
            break;
    }
}

static int print_package_removals(alpm_handle_t *handle)
{
    for (const alpm_list_t *item = alpm_trans_get_remove(handle);
         item != NULL;
         item = item->next) {
        alpm_pkg_t *package = item->data;

        if (package == NULL) {
            fprintf(
                stderr,
                "package-removals-helper: invalid package in removal list\n"
            );
            return -1;
        }

        const char *name = alpm_pkg_get_name(package);

        if (name == NULL || *name == '\0') {
            fprintf(
                stderr,
                "package-removals-helper: package without a valid name\n"
            );
            return -1;
        }

        if (printf("%s\n", name) < 0) {
            fprintf(stderr, "package-removals-helper: stdout write failed\n");
            return -1;
        }
    }

    return 0;
}

int main(void)
{
    int result = EXIT_FAILURE;
    int transaction_initialized = 0;
    alpm_errno_t error = ALPM_ERR_OK;
    alpm_list_t *prepare_data = NULL;
    alpm_handle_t *handle = alpm_initialize(ALPM_ROOT, ALPM_DBPATH, &error);

    if (handle == NULL) {
        fprintf(
            stderr,
            "package-removals-helper: alpm_initialize failed: %s\n",
            alpm_strerror(error)
        );
        return EXIT_FAILURE;
    }

    if (alpm_get_localdb(handle) == NULL) {
        fprintf(stderr, "package-removals-helper: local database unavailable\n");
        goto cleanup;
    }

    if (register_sync_databases(handle) != 0) {
        goto cleanup;
    }

    if (alpm_option_set_questioncb(handle, answer_question, NULL) != 0) {
        fprintf(
            stderr,
            "package-removals-helper: cannot set question callback: %s\n",
            alpm_strerror(alpm_errno(handle))
        );
        goto cleanup;
    }

    if (alpm_trans_init(handle, ALPM_TRANS_FLAG_NOLOCK) != 0) {
        fprintf(
            stderr,
            "package-removals-helper: transaction initialization failed: %s\n",
            alpm_strerror(alpm_errno(handle))
        );
        goto cleanup;
    }

    transaction_initialized = 1;

    if (alpm_sync_sysupgrade(handle, 0) != 0) {
        fprintf(
            stderr,
            "package-removals-helper: system upgrade selection failed: %s\n",
            alpm_strerror(alpm_errno(handle))
        );
        goto cleanup;
    }

    if (alpm_trans_prepare(handle, &prepare_data) != 0) {
        fprintf(
            stderr,
            "package-removals-helper: transaction preparation failed: %s\n",
            alpm_strerror(alpm_errno(handle))
        );
        goto cleanup;
    }

    if (print_package_removals(handle) != 0) {
        goto cleanup;
    }

    result = EXIT_SUCCESS;

cleanup:
    alpm_list_free(prepare_data);

    if (transaction_initialized && alpm_trans_release(handle) != 0) {
        fprintf(
            stderr,
            "package-removals-helper: transaction release failed: %s\n",
            alpm_strerror(alpm_errno(handle))
        );
        result = EXIT_FAILURE;
    }

    if (alpm_release(handle) != 0) {
        fprintf(stderr, "package-removals-helper: alpm_release failed\n");
        result = EXIT_FAILURE;
    }

    return result;
}
