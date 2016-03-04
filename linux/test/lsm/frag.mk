
DIR := test/lsm

SRCDIR_TEST_LSM := $(DIR)
OBJDIR_TEST_LSM := $(OBJDIR)/$(DIR)

OBJDIRS += $(OBJDIR_TEST_LSM)

TEST_INODES := $(OBJDIR_TEST_LSM)/inodes

TEST_LSM_PROGRAMS := $(TEST_INODES)

$(OBJDIR_TEST_LSM)/%.o: $(SRCDIR_TEST_LSM)/%.c
	@echo "+  gcc: $<"
	@mkdir -p $(@D)
	$(V)$(CC) $(CFLAGS) $(INCLUDE) -c -o $@ $<

$(TEST_INODES): $(OBJDIR_TEST_LSM)/inodes.o
	@echo "+   ld: $@"
	$(V)$(CC) -o $@ $^ $(LDFLAGS) 

all: $(TEST_INODES)
