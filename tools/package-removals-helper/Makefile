CC ?= cc
PKG_CONFIG ?= pkg-config

CPPFLAGS += $(shell $(PKG_CONFIG) --cflags libalpm)
CFLAGS ?= -O2
CFLAGS += -std=c17 -Wall -Wextra -Wpedantic -Werror
LDLIBS += $(shell $(PKG_CONFIG) --libs libalpm)

TARGET := package-removals-helper
SOURCES := main.c

.PHONY: all clean check

all: $(TARGET)

$(TARGET): $(SOURCES)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) -o $@ $(SOURCES) $(LDLIBS)

check: $(TARGET)
	./$(TARGET) >/dev/null
	./$(TARGET) --replacements >/dev/null
	./$(TARGET) --additions >/dev/null
	./$(TARGET) --additions-meta >/dev/null
	./$(TARGET) --questions >/dev/null
	@if ./$(TARGET) --unknown >/dev/null 2>&1; then \
		echo "unknown argument unexpectedly accepted" >&2; \
		exit 1; \
	fi

clean:
	rm -f $(TARGET)
