local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

return {
  s(";bash", {
    t("```bash"),
    t({"", ""}),
    i(1),
    t({"", "```"}),
  }),
  
  s(";cs", {
    t("```csharp"),
    t({"", ""}),
    i(1),
    t({"", "```"}),
  }),
  
  s(";html", {
    t("```html"),
    t({"", ""}),
    i(1),
    t({"", "```"}),
  }),
  
  s(";css", {
    t("```css"),
    t({"", ""}),
    i(1),
    t({"", "```"}),
  }),
  
  s(";js", {
    t("```javascript"),
    t({"", ""}),
    i(1),
    t({"", "```"}),
  }),
  
  s(";tsx", {
    t("```tsx"),
    t({"", ""}),
    i(1),
    t({"", "```"}),
  }),
  
  s(";ts", {
    t("```typescript"),
    t({"", ""}),
    i(1),
    t({"", "```"}),
  }),
}
