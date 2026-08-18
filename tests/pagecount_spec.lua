package.path = "./pagecount.koplugin/?.lua;" .. package.path

local PageCount = require("pagecount")

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)))
    end
end

local function fragmentPageCount(lengths, chars_per_page)
    local pages = 0
    for _, length in ipairs(lengths) do
        pages = pages + math.max(1, math.ceil(length / chars_per_page))
    end
    return pages
end

local chars, pages = PageCount.findBestCharsPerPage(10, 500, 3000, function(chars_per_page)
    return fragmentPageCount({ 10000 }, chars_per_page)
end)
assertEqual(pages, 10, "finds an exact page count")
assert(chars >= 500 and chars <= 3000, "exact result stays within bounds")

local _, closest_pages = PageCount.findBestCharsPerPage(5, 500, 3000, function(chars_per_page)
    return fragmentPageCount({ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 }, chars_per_page)
end)
assertEqual(closest_pages, 10, "returns the closest count when fragments impose a minimum")

local _, tied_pages = PageCount.findBestCharsPerPage(10, 1, 10, function(chars_per_page)
    return chars_per_page < 5 and 12 or 8
end)
assertEqual(tied_pages, 12, "prefers the higher page count when differences tie")

local upper_chars = PageCount.findBestCharsPerPage(1, 500, 3000, function(chars_per_page)
    return 4000 - chars_per_page
end)
assertEqual(upper_chars, 3000, "uses the upper character bound for an unreachable low target")

print("pagecount tests passed")
