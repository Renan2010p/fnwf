local transition = {}
local settings = require("scripts.game1.settings")
local draw = require("scripts.core.utils.draw")
local sounds = require("scripts.core.utils.sounds")

local NightTransitionState = {}
NightTransitionState.__index = NightTransitionState

NightTransitionState.NIGHT_DIALOGUES = {
    [2] = {
        { user = "Cedro",     text = "Eai mano! Sobreviveu! Parabéns pela primeira noite!" },
        { user = "Cedro",     text = "Mas não relaxa não... a Noite 2 é mais agitada." },
        { user = "Cedro",     text = "Eu e o Eser vamos nos mover mais rápido agora." },
        { user = "Cientista", text = "Mais rápido?? Já tava difícil!" },
        { user = "Cedro",     text = "Relaxa, você já sabe o esquema. Câmeras, portas, luzes." },
        { user = "Cedro",     text = "Só não gasta energia à toa. Boa sorte!" }
    },
    [3] = {
        { user = "Cedro",     text = "Duas noites! Tá ficando bom nisso hein!" },
        { user = "Cedro",     text = "A Noite 3 é onde começa a ficar sério de verdade." },
        { user = "Cedro",     text = "A gente vai ficar bem mais agressivo agora..." },
        { user = "Cientista", text = "Vocês tão fazendo isso de propósito né?" },
        { user = "Cedro",     text = "Hehehe... talvez. Fica esperto com os dois lados!" }
    }
}

function NightTransitionState.new(night, eng)
    local self = setmetatable({}, NightTransitionState)
    self.night = night
    self.eng = eng
    self.timer = 0.0
    self.done = false
    self.phase = 0
    self.fade_alpha = 255
    self.cedro_avatar = draw.load_sprite(eng, "cedro")
    self.renan_avatar = draw.load_sprite(eng, "renan")

    local raw = NightTransitionState.NIGHT_DIALOGUES[night] or {}
    self.messages = {}
    for _, m in ipairs(raw) do
        table.insert(self.messages, {
            user = m.user,
            avatar = (m.user == "Cedro") and "cedro" or "renan",
            color = (m.user == "Cedro") and { 140, 110, 80 } or { 100, 180, 255 },
            text = m.text
        })
    end

    self.visible_messages = 0
    self.scroll_y = 0.0
    self.target_scroll = 0.0

    sounds.set_engine(eng)
    return self
end

function NightTransitionState:update(dt)
    self.timer = self.timer + dt
    if self.phase == 0 then
        self.fade_alpha = math.max(0, self.fade_alpha - 250 * dt)
        if self.fade_alpha <= 0 then
            self.phase = 1
            sounds.play_sound("notification")
        end
    elseif self.phase == 1 and self.visible_messages == 0 then
        self.visible_messages = 1
        self:_update_scroll()
    elseif self.phase == 2 then
        self.fade_alpha = math.min(255, self.fade_alpha + 250 * dt)
        if self.fade_alpha >= 255 then
            self.done = true
        end
    end

    self.scroll_y = self.scroll_y + (self.target_scroll - self.scroll_y) * 6.0 * dt
end

function NightTransitionState:_update_scroll()
    local th = 15
    local prev = nil
    for i = 1, self.visible_messages do
        local m = self.messages[i]
        if not m then break end
        if prev == m.user then
            th = th + 24
        else
            th = th + (prev and 8 or 0) + 48
        end
        prev = m.user
    end
    local va = settings.SCREEN_HEIGHT - 128
    if th > va then
        self.target_scroll = th - va
    end
end

function NightTransitionState:handle_event(event)
    if event.type == "KEYDOWN" then
        if event.key == 13 or event.key == 32 then
            self:_advance()
        end
    elseif event.type == "MOUSEBUTTONDOWN" then
        self:_advance()
    elseif event.type == "MOUSEWHEEL" then
        self.target_scroll = math.max(0, self.target_scroll - event.y * 40)
    end
end

function NightTransitionState:_advance()
    if self.phase == 0 then
        self.phase = 1
        self.fade_alpha = 0
    elseif self.phase == 1 then
        if self.visible_messages < #self.messages then
            self.visible_messages = self.visible_messages + 1
            self:_update_scroll()
            sounds.play_sound("notification")
        else
            self.phase = 2
            self.fade_alpha = 0
        end
    end
end

function NightTransitionState:draw(eng)
    eng:clear(54, 57, 63, 255)
    if self.phase >= 1 then
        self:_draw_discord(eng)
    end
    draw.static_noise(eng, 0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, 0.005)

    if self.phase == 1 then
        local blink = math.floor(self.timer * 2) % 2 == 0
        if blink then
            local txt = (self.visible_messages < #self.messages) and "ENTER para avançar" or
            string.format("ENTER para começar NOITE %d", self.night)
            draw.text(eng, txt, settings.SCREEN_WIDTH / 2, settings.SCREEN_HEIGHT - 20, 11, { 130, 130, 140 }, 255, true)
        end
    end

    if self.fade_alpha > 0 then
        eng:draw_rect(0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, 54, 57, 63, math.floor(self.fade_alpha))
    end
end

function NightTransitionState:_draw_discord(eng)
    local sw = 240
    eng:draw_rect(0, 0, sw, settings.SCREEN_HEIGHT, 47, 49, 54, 255)
    eng:draw_rect(0, 0, sw, 48, 40, 43, 48, 255)
    draw.text(eng, "Máfia dos Tabacudos", 15, 14, 14, { 220, 220, 220 }, 255, false)
    eng:draw_line(0, 48, sw, 48, 30, 33, 36, 255)

    local cx, cw = sw, settings.SCREEN_WIDTH - sw
    eng:draw_rect(cx, 0, cw, 48, 54, 57, 63, 255)
    draw.text(eng, "# segurança", cx + 18, 14, 15, { 220, 220, 220 }, 255, false)

    local my = 63 - math.floor(self.scroll_y)
    local prev = nil
    draw.text(eng, string.format("--- NOITE %d ---", self.night), cx + cw / 2, my, 12, { 130, 130, 140 }, 255, true)
    my = my + 30

    for i = 1, self.visible_messages do
        local m = self.messages[i]
        if not m then break end

        if prev == m.user then
            draw.text(eng, m.text, cx + 75, my, 14, { 220, 220, 220 }, 255, false)
            my = my + 24
        else
            my = my + (prev and 8 or 0)
            eng:draw_circle(cx + 40, my + 20, 20, 80, 80, 90, 255)
            local av = (m.avatar == "cedro") and self.cedro_avatar or self.renan_avatar
            if av then
                eng:draw_texture(av, cx + 20, my, 40, 40)
            end
            draw.text(eng, m.user, cx + 75, my, 14, m.color, 255, false)
            my = my + 22
            draw.text(eng, m.text, cx + 75, my, 14, { 220, 220, 220 }, 255, false)
            my = my + 24
        end
        prev = m.user
    end

    eng:draw_rect(cx + 16, settings.SCREEN_HEIGHT - 65, cw - 32, 44, 64, 68, 75, 255)
    draw.text(eng, "Mensagem #segurança", cx + 30, settings.SCREEN_HEIGHT - 52, 13, { 100, 100, 110 }, 255, false)
end

function NightTransitionState:is_done()
    return self.done
end

transition.NightTransitionState = NightTransitionState
return transition