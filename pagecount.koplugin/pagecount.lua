local PageCount = {}

local function isBetterResult(candidate_pages, candidate_chars, best_pages, best_chars, target_pages)
    if not best_pages then
        return true
    end

    local candidate_difference = math.abs(candidate_pages - target_pages)
    local best_difference = math.abs(best_pages - target_pages)
    if candidate_difference ~= best_difference then
        return candidate_difference < best_difference
    end

    local candidate_is_over = candidate_pages >= target_pages
    local best_is_over = best_pages >= target_pages
    if candidate_is_over ~= best_is_over then
        return candidate_is_over
    end

    return candidate_chars < best_chars
end

function PageCount.findBestCharsPerPage(target_pages, chars_min, chars_max, get_page_count)
    assert(target_pages >= 1, "target_pages must be positive")
    assert(chars_min >= 1, "chars_min must be positive")
    assert(chars_max >= chars_min, "chars_max must not be less than chars_min")

    local cache = {}
    local best_chars
    local best_pages

    local function measure(chars)
        if cache[chars] == nil then
            cache[chars] = get_page_count(chars)
        end
        local pages = cache[chars]
        if isBetterResult(pages, chars, best_pages, best_chars, target_pages) then
            best_chars = chars
            best_pages = pages
        end
        return pages
    end

    local low = chars_min
    local high = chars_max
    while low <= high do
        local chars = math.floor((low + high) / 2)
        local pages = measure(chars)
        if pages == target_pages then
            return chars, pages
        elseif pages > target_pages then
            low = chars + 1
        else
            high = chars - 1
        end
    end

    if high >= chars_min then
        measure(high)
    end
    if low <= chars_max then
        measure(low)
    end

    return best_chars, best_pages
end

return PageCount
