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

typedef enum {
    OUTPUT_REMOVALS,
    OUTPUT_REPLACEMENTS,
    OUTPUT_ADDITIONS,
    OUTPUT_ADDITIONS_META
} output_mode_t;

typedef struct {
    output_mode_t mode;
    alpm_list_t *replacements;
    int collection_failed;
} question_context_t;

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

static int collect_replacement(question_context_t *context, alpm_question_t *question)
{
    alpm_pkg_t *old_package = question->replace.oldpkg;
    alpm_pkg_t *new_package = question->replace.newpkg;

    if (old_package == NULL || new_package == NULL) {
        return -1;
    }

    const char *old_name = alpm_pkg_get_name(old_package);
    const char *new_name = alpm_pkg_get_name(new_package);

    if (old_name == NULL || *old_name == '\0'
        || new_name == NULL || *new_name == '\0') {
        return -1;
    }

    const size_t line_size = strlen(old_name) + strlen(new_name) + 2;
    char *line = malloc(line_size);

    if (line == NULL) {
        return -1;
    }

    if (snprintf(line, line_size, "%s|%s", old_name, new_name) < 0) {
        free(line);
        return -1;
    }

    context->replacements = alpm_list_add(context->replacements, line);
    return 0;
}

static void answer_question(void *context_data, alpm_question_t *question)
{
    question_context_t *context = context_data;

    switch (question->type) {
        case ALPM_QUESTION_REPLACE_PKG:
            if (context != NULL
                && context->mode == OUTPUT_REPLACEMENTS
                && collect_replacement(context, question) != 0) {
                context->collection_failed = 1;
            }
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

static int print_package_names(const alpm_list_t *packages, const char *kind)
{
    for (const alpm_list_t *item = packages;
         item != NULL;
         item = item->next) {
        alpm_pkg_t *package = item->data;

        if (package == NULL) {
            fprintf(
                stderr,
                "package-removals-helper: invalid package in %s list\n",
                kind
            );
            return -1;
        }

        const char *name = alpm_pkg_get_name(package);

        if (name == NULL || *name == '\0') {
            fprintf(
                stderr,
                "package-removals-helper: package without a valid name in %s list\n",
                kind
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

static int metadata_field_is_valid(const char *field)
{
    return field != NULL && *field != '\0' && strchr(field, '|') == NULL;
}

static int print_package_metadata(const alpm_list_t *packages)
{
    for (const alpm_list_t *item = packages;
         item != NULL;
         item = item->next) {
        alpm_pkg_t *package = item->data;

        if (package == NULL) {
            fprintf(stderr, "package-removals-helper: invalid addition metadata\n");
            return -1;
        }

        alpm_db_t *database = alpm_pkg_get_db(package);
        const char *repository = database == NULL ? NULL : alpm_db_get_name(database);
        const char *name = alpm_pkg_get_name(package);
        const char *version = alpm_pkg_get_version(package);

        if (!metadata_field_is_valid(repository)
            || !metadata_field_is_valid(name)
            || !metadata_field_is_valid(version)) {
            fprintf(
                stderr,
                "package-removals-helper: invalid addition metadata field\n"
            );
            return -1;
        }

        if (printf("%s|%s|%s\n", repository, name, version) < 0) {
            fprintf(stderr, "package-removals-helper: stdout write failed\n");
            return -1;
        }
    }

    return 0;
}

static int print_package_replacements(const question_context_t *context)
{
    for (const alpm_list_t *item = context->replacements;
         item != NULL;
         item = item->next) {
        const char *replacement = item->data;

        if (replacement == NULL || *replacement == '\0') {
            fprintf(
                stderr,
                "package-removals-helper: invalid replacement entry\n"
            );
            return -1;
        }

        if (printf("%s\n", replacement) < 0) {
            fprintf(stderr, "package-removals-helper: stdout write failed\n");
            return -1;
        }
    }

    return 0;
}

static int parse_output_mode(int argc, char **argv, output_mode_t *mode)
{
    if (argc == 1) {
        *mode = OUTPUT_REMOVALS;
        return 0;
    }

    if (argc == 2 && strcmp(argv[1], "--replacements") == 0) {
        *mode = OUTPUT_REPLACEMENTS;
        return 0;
    }

    if (argc == 2 && strcmp(argv[1], "--additions") == 0) {
        *mode = OUTPUT_ADDITIONS;
        return 0;
    }

    if (argc == 2 && strcmp(argv[1], "--additions-meta") == 0) {
        *mode = OUTPUT_ADDITIONS_META;
        return 0;
    }

    fprintf(
        stderr,
        "usage: package-removals-helper "
        "[--replacements|--additions|--additions-meta]\n"
    );
    return -1;
}

int main(int argc, char **argv)
{
    int result = EXIT_FAILURE;
    int transaction_initialized = 0;
    alpm_errno_t error = ALPM_ERR_OK;
    alpm_list_t *prepare_data = NULL;
    output_mode_t mode = OUTPUT_REMOVALS;
    question_context_t question_context = {
        .mode = OUTPUT_REMOVALS,
        .replacements = NULL,
        .collection_failed = 0,
    };

    if (parse_output_mode(argc, argv, &mode) != 0) {
        return EXIT_FAILURE;
    }

    question_context.mode = mode;

    const char *database_path = getenv("SMART_UPDATE_ALPM_DBPATH");

    if (database_path == NULL || *database_path == '\0') {
        database_path = ALPM_DBPATH;
    } else if (database_path[0] != '/'
               || strstr(database_path, "..") != NULL) {
        fprintf(stderr, "package-removals-helper: invalid database path\n");
        return EXIT_FAILURE;
    }

    alpm_handle_t *handle = alpm_initialize(ALPM_ROOT, database_path, &error);

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

    if (alpm_option_set_questioncb(handle, answer_question, &question_context) != 0) {
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

    if (question_context.collection_failed) {
        fprintf(
            stderr,
            "package-removals-helper: replacement collection failed\n"
        );
        goto cleanup;
    }

    if (mode == OUTPUT_REPLACEMENTS) {
        if (print_package_replacements(&question_context) != 0) {
            goto cleanup;
        }
    } else if (mode == OUTPUT_ADDITIONS) {
        if (print_package_names(alpm_trans_get_add(handle), "addition") != 0) {
            goto cleanup;
        }
    } else if (mode == OUTPUT_ADDITIONS_META) {
        if (print_package_metadata(alpm_trans_get_add(handle)) != 0) {
            goto cleanup;
        }
    } else if (print_package_names(alpm_trans_get_remove(handle), "removal") != 0) {
        goto cleanup;
    }

    result = EXIT_SUCCESS;

cleanup:
    alpm_list_free(prepare_data);
    alpm_list_free_inner(question_context.replacements, free);
    alpm_list_free(question_context.replacements);

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
