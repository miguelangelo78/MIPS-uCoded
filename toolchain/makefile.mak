SRC = src
BIN = bin
IVERI = iverilog
VERISIM = vvp
WAVE = gtkwave
WAVESPATH = waves

VERIFLAGS = -g2012 -Isrc
SIMFLAGS = 
WAVEFLAGS =

CWD = $(CURDIR)
makefile_dir:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

##### Compilation rules and objects: #####
#__GENMAKE__
BINS = $(BIN)/datapath.o \
	$(BIN)/datapath_multicycle.o \
	$(BIN)/microcode.o 

$(BIN)/datapath.o: $(SRC)/datapath.sv
	$(IVERI) -o $@ $(VERIFLAGS) $^

$(BIN)/datapath_multicycle.o: $(SRC)/datapath_multicycle.sv
	$(IVERI) -o $@ $(VERIFLAGS) $^

$(BIN)/microcode.o: $(SRC)/microcode.sv
	$(IVERI) -o $@ $(VERIFLAGS) $^

#__GENMAKE_END__

##### Main rules:
# Compile:
all: $(BINS)
	@printf "Finished!\n"

# Simulate:
%:
	@cd $(WAVESPATH) && $(VERISIM) $(CWD)/$(BIN)/$(basename $@).o
	
# GTKWave:
w%:
	$(WAVE) $(WAVESPATH)/$(basename $(@:w%=%)).vcd

clean:
	$(RM) $(BIN)/*

clean_waves:
	$(RM) $(WAVESPATH)/*