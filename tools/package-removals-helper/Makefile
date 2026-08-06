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
	$(CC) $(CPPFLAGS) $(CFLAGS) -o $@ $(SOURCES) $(LDLIBS)

check: $(TARGET)
	./$(TARGET)

clean:
	rm -f $(TARGET)
