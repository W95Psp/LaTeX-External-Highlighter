# Highlighter using Emacs or Vim syntax files in LaTeX
Use `emacs` or `vim` (or any external tool) to generate highlighted code, instead of lstlisting.

## How to use
### Prepare
 - Use LuaTeX
 - Configure LuaTeX so that Lua scripts can use filesystem: `--shell-escape`
 - Add `extern_highlighter.lua` somewhere near your LaTeX sources (i.e. create a `lua` subdirectory and put it in `./lua/extern_highlighter.lua`)
 - Create a `highlighter_cache` directory just aside your main `tex` file
 - Before your `\begin{document}` put: (here, it is configured to consider source as Javascript by default, just change `"js"` for other behaviours)
 ```tex
\directlua{extern_highlighter = require "lua/extern_highlighter"}
\directlua{finalize = extern_highlighter.setup(nil, "js")}
```
 - Just before your `\end{document}` put:
 ```tex
\directlua{finalize()}
```

### Use
Just use the new `showcode` environment:
```tex
\begin{showcode}
  function sample(){
  	hey = 2;
  	return 21 * hey;	
  }
\end{showcode}
```

To specify explicitly a language:
```tex
\begin{showcode}
  [lang=html]
  <p>Hello world</p>
\end{showcode}
```

Then compile two times. (needed only when `showcode` envs content changes)

### Changing the `emacs`/whatever rendering script
When calling to `extern_highlighter.setup`, just specify as first argument a custom function generating the command line to be generated. See `extern_highlighter.config_print_emacs` in the code for an example.

### Other options
```lua
extern_highlighter.setup(command, def_ext, cache_path, ename)
```

## How it works
- extract things in `showcode` environments
- do md5 of the content of such environments
- write a file named after that md5
- if a `pdf` of that same name exists, then include it
- otherwise, generate the pdf

## Note
Note: it takes care of removing superfluous tabs, if you don't want that, look at the function `includeCode`