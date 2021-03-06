# Common Makefile for xzd_baremetal.
#

OBJ_DIR=$(CURDIR)
TOPLEVEL_DIR=$(CURDIR)

include Config.mk

include $(TOPLEVEL_DIR)/config/Bare.mk


DEF_CFLAGS += $(flags-y)

# Symlinks and headers that must be created before building the C files
GENERATED_HEADERS := $(ARCH_LINKS) include

EXTRA_DEPS += $(GENERATED_HEADERS)

# Include common bare metal makerules.
include bare.mk

# Set tester flags
# CFLAGS += -DBLKTEST_WRITE

# Define some default flags for linking.
LDLIBS := 
APP_LDLIBS := 
LDARCHLIB := -L$(OBJ_DIR)/$(TARGET_ARCH_DIR) -l$(ARCH_LIB_NAME)
LDFLAGS_FINAL := -T $(TARGET_ARCH_DIR)/xzd_bare.lds

# Prefix for global API names. All other symbols are localised before
# linking with EXTRA_OBJS.
# GLOBAL_PREFIX := xenos_
EXTRA_OBJS = 

TARGET := xzd_bare

# Subdirectories common to bare metal
SUBDIRS := 
FDT_SRC :=

# Need libgcc.a for division helpers
# LDLIBS += `$(CC) -print-libgcc-file-name`


# src-y += main.c


# The common bare metal objects to build.
APP_OBJS :=
OBJS := $(patsubst %.c,$(OBJ_DIR)/%.o,$(src-y))
PAYLOAD_O := $(OBJ_DIR)/payload.o

.PHONY: default
default: $(OBJ_DIR)/$(TARGET)

# Create special architecture specific links. The function arch_links
# has to be defined in arch.mk (see include above).
ifneq ($(ARCH_LINKS),)
$(ARCH_LINKS):
	$(arch_links)
endif

# Used by stubdom's Makefile
.PHONY: links
links: $(GENERATED_HEADERS)

include/xen:
	ln -sf ../../../xen/include/public $@

.PHONY: arch_lib
arch_lib:
	$(MAKE) --directory=$(TARGET_ARCH_DIR) OBJ_DIR=$(OBJ_DIR)/$(TARGET_ARCH_DIR) || exit 1;

OBJS := $(filter-out $(OBJ_DIR)/lwip%.o $(LWO), $(OBJS))

$(OBJ_DIR)/$(TARGET)_app.o: $(APP_OBJS) app.lds
	$(LD) -r -d $(LDFLAGS) -\( $^ -\) $(APP_LDLIBS) --undefined main -o $@

ifneq ($(APP_OBJS),)
APP_O=$(OBJ_DIR)/$(TARGET)_app.o 
endif

$(OBJ_DIR)/app.bin:
	@if [ -e $(OBJ_DIR)/app.bin ]; then \
		echo "!! app.bin exists !!" ; \
	else \
		echo "!! Creating dummy app.bin !!"; \
		echo -n -e \\x00\\x00\\x00\\x14 > app.bin; \
	fi;

$(OBJ_DIR)/payload.o: $(OBJ_DIR)/app.bin
	aarch64-none-elf-objcopy -I binary -O elf64-littleaarch64 -B aarch64 --rename .data=.payload_data --redefine-sym _binary_app_bin_start=_payload_start --redefine-sym _binary_app_bin_end=_payload_end --redefine-sym _binary_app_bin_size=_payload_size app.bin payload.o


$(OBJ_DIR)/$(TARGET): $(OBJS) $(APP_O) $(PAYLOAD_O) arch_lib
	$(LD) -r $(LDFLAGS) $(HEAD_OBJ) $(APP_O) $(OBJS) $(LDARCHLIB) $(LDLIBS) -o $@.o
	$(OBJCOPY) -w -G _text $@.o $@.o

	$(LD) $(LDFLAGS) $(LDFLAGS_FINAL) $@.o $(PAYLOAD_O) $(EXTRA_OBJS) -o $@
	$(OBJCOPY) -O binary $@ $@.img

.PHONY: docs
docs:
	mkdocs build --clean

.PHONY: clean arch_clean clean-docs

clean-docs:
	rm -rf site	

arch_clean:
	$(MAKE) --directory=$(TARGET_ARCH_DIR) OBJ_DIR=$(OBJ_DIR)/$(TARGET_ARCH_DIR) clean || exit 1;

clean:	arch_clean clean-docs
	for dir in $(addprefix $(OBJ_DIR)/,$(SUBDIRS)); do \
		rm -f $$dir/*.o; \
	done
	rm -f $(OBJ_DIR)/*.o *~ $(OBJ_DIR)/core $(OBJ_DIR)/$(TARGET).elf $(OBJ_DIR)/$(TARGET).raw $(OBJ_DIR)/$(TARGET) $(OBJ_DIR)/$(TARGET).img
	find . $(OBJ_DIR) -type l | xargs rm -f
	$(RM) $(OBJ_DIR)/lwip.a $(LWO)
	rm -f tags TAGS
	rm -f $(OBJ_DIR)/app.bin

define all_sources
     ( find . -follow -name SCCS -prune -o -name '*.[chS]' -print )
endef

.PHONY: cscope
cscope:
	$(all_sources) > cscope.files
	cscope -k -b -q
    
.PHONY: tags
tags:
	$(all_sources) | xargs ctags

.PHONY: TAGS
TAGS:
	$(all_sources) | xargs etags
