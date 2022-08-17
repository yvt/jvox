
COFFEE=coffee

default:		all

all:			index.js jvox.js

index.js:		index.coffee
				$(COFFEE) -c index.coffee
jvox.js:		jvox.coffee
				$(COFFEE) -c jvox.coffee
