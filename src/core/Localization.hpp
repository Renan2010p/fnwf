#pragma once

#include <string>
#include <unordered_map>

namespace fnwf {

class Localization
{
public:
    static auto set_language(const std::string& lang) -> void;
    static auto get_language() -> const std::string&;
    static auto get_text(const std::string& key) -> const std::string&;

private:
    static inline std::string s_current_lang{"pt"};
    static inline std::unordered_map<std::string, std::unordered_map<std::string, std::string>>
        s_translations{};
    static inline bool s_initialized{false};
    static auto ensure_initialized() -> void;
};

}  // namespace fnwf
