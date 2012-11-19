SRCS = Brain.oz Gui.oz Utils.oz Config.oz Home.oz Player.oz Square.oz
OBJS = $(SRCS:.oz=.ozf)
MAIN = INGI-of-Empires.oz
EXECUTABLE = INGI-of-Empires

.PHONY: clean

$(EXECUTABLE): $(OBJS) $(MAIN)
	ozc -x $(MAIN)

Brain.ozf: Brain.oz Config.ozf
	ozc -c Brain.oz -o Brain.ozf

Gui.ozf: Gui.oz Utils.ozf
	ozc -c Gui.oz -o Gui.ozf

Utils.ozf: Utils.oz Config.ozf
	ozc -c Utils.oz -o Utils.ozf

Config.ozf: Config.oz
	ozc -c Config.oz -o Config.ozf

Home.ozf: Home.oz Config.ozf Utils.ozf
	ozc -c Home.oz -o Home.ozf

Player.ozf: Player.oz Config.ozf Utils.ozf Brain.ozf
	ozc -c Player.oz -o Player.ozf

Square.ozf: Square.oz Config.ozf Utils.ozf
	ozc -c Square.oz -o Square.ozf

all: $(EXECUTABLE)

clean:
	rm -f $(OBJS) $(EXECUTABLE)
