-- This project is licensed under the MIT No Attribution license.
--
-- Copyright (c) 2024 natmark (Atsuya Sato)
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

obs = obslua

-- 説明文
function script_description()
    return "ココフォリアのルームID自動置き換えスクリプト"
end

-- スクリプトに対する編集可能なプロパティ
function script_properties()
    local props = obs.obs_properties_create()
    obs.obs_properties_add_text(props, "room_id", "https://ccfolia.com/rooms/ に続く9桁の文字列を入れてください", obs.OBS_TEXT_DEFAULT)
    return props
end

-- プロパティ変更された際に都度実行される関数
function script_update(settings)
    local room_id = obs.obs_data_get_string(settings, "room_id")

    -- 9桁入力されるまでは無視
    local len = string.len(room_id)
    if 9 ~= len then
        return
    end

    -- 英数字+アンダーバー以外が入力された場合はエラー
    local check_format = string.find(room_id, '[0-9a-zA-Z_]+')
    if check_format == nil then
        obs.script_log(obs.LOG_ERROR, "ルームIDの形式が不正です")
        return
    end

    obs.script_log(obs.LOG_OUTPUT, string.format('== [%s] スクリプトの実行を開始します == ', os.date()))

    local scenes = obs.obs_frontend_get_scenes()

    for _, scene_source in ipairs(scenes) do
        -- シーン名出力
        local scene_name = obs.obs_source_get_name(scene_source)
        obs.script_log(obs.LOG_INFO, string.format('↓[%s] 内のブラウザソースを探索します↓', scene_name))

        local scene = obs.obs_scene_from_source(scene_source)
        scene_scanner(scene, room_id)
    end

    obs.source_list_release(scenes)

    obs.script_log(obs.LOG_OUTPUT, string.format('== [%s] スクリプトの実行が完了しました == ', os.date()))
end

-- シーンに紐づくソースを探索する
function scene_scanner(scene, room_id)
    local scene_items = obs.obs_scene_enum_items(scene)

    for i, scene_item in ipairs(scene_items) do
        local scene_item_source = obs.obs_sceneitem_get_source(scene_item)
        local group = obs.obs_group_from_source(scene_item_source)

        if group ~= nil then
            -- グループ名は出力しなくてもいいかも
            -- local group_name = obs.obs_source_get_name(scene_item_source)
            -- obs.script_log(obs.LOG_INFO, string.format('グループが見つかりました: %s', group_name))        
            group_scanner(group, room_id)
        else
            scene_item_scanner(scene_item_source, room_id)
        end
    end

    obs.sceneitem_list_release(scene_items)
end

-- グループに紐づくソースを探索する
function group_scanner(group, room_id)
    local group_items = obs.obs_scene_enum_items(group)

    for _, group_item in ipairs(group_items) do
        local scene_item_source = obs.obs_sceneitem_get_source(group_item)
        scene_item_scanner(scene_item_source, room_id)
    end

    obs.sceneitem_list_release(groupitems)
end

-- ソースに対して処理を行う
function scene_item_scanner(scene_item_source, room_id)
    local scene_item_name = obs.obs_source_get_name(scene_item_source)
    local scene_item_source_id = obs.obs_source_get_id(scene_item_source)

    -- ブラウザソースでないなら無視
    if scene_item_source_id ~= 'browser_source' then
        return
    end

    local settings = obs.obs_source_get_settings(scene_item_source)
    local url = obs.obs_data_get_string(settings, 'url')

    local replaced = string.gsub(url, '^(https://ccfolia.com/rooms/)([0-9a-zA-Z_]+)$', string.format('%%1%s', room_id))

    -- 置き換えが発生してないなら無視
    if url == replaced then
        return
    end

    obs.script_log(obs.LOG_INFO, string.format('> [%s] のURLを %s に置き換えました', scene_item_name, replaced))

    obs.obs_data_set_string(settings, 'url', replaced)
    obs.obs_source_update(source, settings)
    obs.obs_data_release(settings)

    force_reload_browser(scene_item_source)
end

-- FPS変更することで強制的にブラウザをリロードできる
function force_reload_browser(source)
    local settings = obs.obs_source_get_settings(source)
    local fps = obs.obs_data_get_int(settings, "fps")
    if fps % 2 == 0 then
        obs.obs_data_set_int(settings, "fps", fps + 1)
    else
        obs.obs_data_set_int(settings, "fps", fps - 1)
    end
    obs.obs_source_update(source, settings)
    obs.obs_data_release(settings)
end
