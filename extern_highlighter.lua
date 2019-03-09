local extern_highlighter = {}

local md5 = require 'md5'
local lfs = require 'lfs'

function table.contains(tbl, value)
   for i,v in ipairs(tbl) do
      if v == value then
	 return true
      end
   end
   return false
end

_list_envs = {}

-- generic configuration that invokes emacs to highlight a file
function extern_highlighter.config_print_emacs(cache_path, source_path, pdf_out_path, ext)
   local tmpPath = cache_path.."/tmp.html"
   local toTmp = [[emacs "]]..source_path..[[" --eval="(dolist (i custom-enabled-themes) (disable-theme i))" --eval="(htmlfontify-buffer)" --eval="(write-file \"]]..tmpPath..[[\")" --eval="(kill-emacs)"]]
   return toTmp.."; wkhtmltopdf \""..tmpPath.."\" "..pdf_out_path.."; rm \""..tmpPath.."\"; pdfcrop "..pdf_out_path.." "..pdf_out_path
end

-- specific configuration using some /opt/print-fst.sh script
function extern_highlighter.config_print_emacs_fst(cache_path, source_path, pdf_out_path, ext)
   return "bash /opt/print-fst.sh "..source_path.." | wkhtmltopdf - "..pdf_out_path.."; pdfcrop "..pdf_out_path.." "..pdf_out_path
end

function extern_highlighter.config_print_emacs_ofst(cache_path, source_path, pdf_out_path, ext)
   if ext == "fst" then
      return extern_highlighter.config_print_emacs_fst(cache_path, source_path, pdf_out_path, ext)
   else
      return extern_highlighter.config_print_emacs(cache_path, source_path, pdf_out_path, ext)
   end
end

function extern_highlighter.setup(command, def_ext, cache_path, ename)
   def_ext 	= def_ext or "hs"
   ename 		= ename	  or "showcode"
   command		= command or extern_highlighter.config_print_emacs
   cache_path 	= cache_path or lfs.currentdir().."/highlighter_cache/"
   lfs.mkdir(cache_path)
   _list_envs[ename] = {def_ext = def_ext, cache_path = cache_path, useful_files = {}, command = command, codesToPrint = {}}
   local a = [[\directlua{extern_highlighter.start_recording("]] .. ename .. [[")}]]
   local b = [[\directlua{extern_highlighter.stop_recording("]] .. ename .. [[", extern_highlighter.showcodeEnv)}]]
   local newenv = [[\newenvironment{]] .. ename .. [[}{]]..a..[[}{]]..b..[[}]]
   tex.sprint(newenv)
   return finalize(ename)
end

function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end
function includeCode(ename, str, ext)
   local codesToPrint = _list_envs[ename].codesToPrint
   local useful_files = _list_envs[ename].useful_files
   str = string.gsub(str, "\\&", "&")
   local hash = md5.sumhexa(str)
   local source = hash .. "." .. ext
   local pdf = hash .. "_" .. ext .. ".pdf"
   local path = _list_envs[ename].cache_path

   useful_files[#useful_files + 1] = source
   useful_files[#useful_files + 1] = pdf

   if not file_exists(path .. source) then
      local file = io.open(path .. source, "w")
      file:write(str)
      file:close()
   end

   if file_exists(path .. pdf) then
      tex.print("\\includegraphics{\\detokenize{"..path.."/" .. pdf .. "}}")
   else
      codesToPrint[#codesToPrint + 1] = {source_path = path .. source, pdf_out_path = path .. pdf, ext = ext}
      tex.print([[{\color{red}\Huge Source processed: recompile me!}]])
   end
end
function finalize(ename)
   return function()
      local cache_path = _list_envs[ename].cache_path
      local command 	 = _list_envs[ename].command
      local codesToPrint = _list_envs[ename].codesToPrint
      cleanup(cache_path, _list_envs[ename].useful_files)
      if #codesToPrint > 0 then
	 local str = ""
	 for i,v in ipairs(codesToPrint) do
	    str = str .. command(cache_path, '"'..v.source_path..'"', '"'..v.pdf_out_path..'"', v.ext) .. ';';
	 end
	 local fname = cache_path .. "/render.sh"
	 local file = io.open(fname, "w")
	 file:write(str .. "rm " .. fname)
	 file:close()
	 os.execute("bash "..fname)
	 tex.print([[{\color{red}\Huge Some sources were processed, recompilation needed!}]])
      end
   end
end
function cleanup(directory, but)
   for v in lfs.dir(directory) do
      if table.contains(but, v) == false then
	 os.remove(directory.."/"..v)
      end
   end
end
function extern_highlighter.showcodeEnv(ename, str)
   for i,v in ipairs(_list_envs) do
      print(i,v)
   end

   local cache_path = _list_envs[ename].cache_path
   local def_ext = _list_envs[ename].def_ext
   local lang = def_ext
   str = string.gsub(str, "([^\n][ \t]*)", function(a) return string.gsub(a, "\t", "    ") end);
   str = string.gsub(str, "^%s*%[lang=(%a+)%][\t ]*\n?", function(mlang) lang = mlang return "" end)
   local lines = string.gmatch(str, "[^\n]+")
   tabs = math.huge
   for k in lines do
      tabs = math.min(#string.match(k, "^%s+"), tabs)
   end
   if tabs == math.huge then
      tabs = 0
   end
   tstr = ""
   for i=1,tabs do
      tstr = tstr .. " "
   end
   str = string.gsub(str, "^" .. tstr, "")
   str = string.gsub(str, "\n" .. tstr, "\n")
   includeCode(ename, str, lang)
end

mybuf = ""
function extern_highlighter.start_recording(verb)
   local end_verb = '%s*\\end{'..verb..'}'

   function readbuf( buf )
      if buf:match(end_verb) then
	 return buf
      end
      mybuf = mybuf .. buf .. "\n" 
      return ""
   end
   luatexbase.add_to_callback('process_input_buffer', readbuf, 'readbuf')
end

function extern_highlighter.stop_recording(verb, action)
   luatexbase.remove_from_callback('process_input_buffer', 'readbuf')
   local buf_without_end = mybuf:gsub("\\end{"..verb.."}\n","")
   mybuf = ""
   action(verb, buf_without_end)
end

return extern_highlighter
