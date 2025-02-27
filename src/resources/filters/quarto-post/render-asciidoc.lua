-- render-asciidoc.lua
-- Copyright (C) 2020-2022 Posit Software, PBC


local kAsciidocNativeCites = 'use-asciidoc-native-cites'

function renderAsciidoc()   

  -- This only applies to asciidoc output
  if not quarto.doc.isFormat("asciidoc") then
    return {}
  end

  local hasMath = false

  return {
    Meta = function(meta)
      if hasMath then
        meta['asciidoc-stem'] = 'latexmath'
      end 

      -- We construct the title with cross ref information into the metadata
      -- if we see such a title, we need to move the identifier up outside the title
      local titleInlines = meta['title']
      if #titleInlines == 1 and titleInlines[1].t == 'Span' then ---@diagnostic disable-line
        ---@type pandoc.Span
        local span = titleInlines[1]
        local identifier = span.identifier
        if refType(identifier) == "sec" then
          -- this is a chapter title, tear out the id and make it ourselves
          local titleContents = pandoc.write(pandoc.Pandoc({span.content}), "asciidoc")
          meta['title'] = pandoc.RawInline("asciidoc", titleContents)
          meta['title-prefix'] = pandoc.RawInline("asciidoc", "[[" .. identifier .. "]]")
        end
      end

      return meta
    end,
    Math = function(el)
      hasMath = true;
    end,
    Cite = function(el) 
      -- If quarto is going to be processing the cites, go ahead and convert
      -- them to a native cite
      if param(kAsciidocNativeCites) then
        local citesStr = table.concat(el.citations:map(function (cite) 
          return '<<' .. cite.id .. '>>'
        end))
        return pandoc.RawInline("asciidoc", citesStr);
      end
    end,
    Callout = function(el) 
      -- callout -> admonition types pass through
      local admonitionType = el.type:upper();

      -- render the callout contents
      local admonitionContents = pandoc.write(pandoc.Pandoc(el.content), "asciidoc")

      local admonitionStr;
      if el.title then
        -- A titled admonition
        local admonitionTitle = pandoc.write(pandoc.Pandoc(el.title), "asciidoc")
        admonitionStr = "[" .. admonitionType .. "]\n." .. admonitionTitle .. "====\n" .. admonitionContents .. "====\n\n" 
      else
        -- A titleless admonition
          admonitionStr = "[" .. admonitionType .. "]\n====\n" .. admonitionContents .. "====\n\n" 
      end
      return pandoc.RawBlock("asciidoc", admonitionStr)
    end,
    Inlines = function(el)
      -- Walk inlines and see if there is an inline code followed directly by a note. 
      -- If there is, place a space there (because otherwise asciidoctor may be very confused)
      for i, v in ipairs(el) do

        if v.t == "Code" then
          if el[i+1] and el[i+1].t == "Note" then

            local noteEl = el[i+1]
            -- if the note contains a code inline, we need to add a space
            local hasCode = false
            pandoc.walk_inline(noteEl, {
              Code = function(_el)
                hasCode = true
              end
            })

            -- insert a space
            if hasCode then
              table.insert(el, i+1, pandoc.RawInline("asciidoc", "{empty}"))
            end
          end
        end
        
      end
      return el

    end
  }
end


