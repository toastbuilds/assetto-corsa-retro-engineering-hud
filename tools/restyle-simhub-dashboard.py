import argparse
import copy
import hashlib
import io
import json
import math
from pathlib import Path
import zipfile

from PIL import Image, ImageDraw, ImageFilter


MODEL_PREFIX = 'SimHub.Plugins.OutputPlugins.GraphicalDash.Models.'
MODEL_SUFFIX = ', SimHub.Plugins'
TRANSPARENT = '#00FFFFFF'
PRIMARY = '#FFF2DBAE'
AMBER = '#FFFFC46B'
SECONDARY = '#FFBE9760'
CYAN = '#FF68B7D6'
DIM = '#FF332519'
SCALE = 3


def walk_items(items):
    for item in items:
        yield item
        yield from walk_items(item.get('Childrens', []))


def argb_to_rgba(value):
    digits = value.lstrip('#')
    if len(digits) == 6:
        digits = 'FF' + digits
    return tuple(int(digits[offset:offset + 2], 16) for offset in (2, 4, 6, 0))


def polygon_points(width, height, cut, inset=0):
    return [(inset + cut, inset), (width - inset - cut, inset),
            (width - inset, inset + cut), (width - inset, height - inset - cut),
            (width - inset - cut, height - inset), (inset + cut, height - inset),
            (inset, height - inset - cut), (inset, inset + cut)]


def new_item(kind, name, left, top, width, height, **properties):
    return {'$type': MODEL_PREFIX + kind + MODEL_SUFFIX, 'Name': name,
            'Left': left, 'Top': top, 'Width': width, 'Height': height,
            'BackgroundColor': TRANSPARENT, 'Visible': True,
            'BlinkPhasisInverted': False, 'RenderingSkip': 0,
            'MinimumRefreshIntervalMS': 0, **properties}


def text_item(name, text, left, top, width, height, font_size, color=PRIMARY):
    return new_item('TextItem', name, left, top, width, height,
                    IsTextItem=True, Font='Consolas', FontSize=font_size,
                    Text=text, TextColor=color, HorizontalAlignment=1,
                    VerticalAlignment=1)


class AssetLibrary:
    def __init__(self, dashboard, source_archive):
        self.dashboard = dashboard
        with zipfile.ZipFile(source_archive) as archive:
            self.contents = {entry.filename: archive.read(entry.filename)
                             for entry in archive.infolist()}
        self.cache = {}
        self.generated_names = []

    def add(self, name, image):
        buffer = io.BytesIO()
        image.save(buffer, format='PNG', optimize=True)
        content = buffer.getvalue()
        self.contents[name + '.png'] = content
        self.dashboard['Images'].append({
            'Name': name, 'Extension': '.png', 'Modified': True,
            'Optimized': True, 'Width': image.width, 'Height': image.height,
            'Length': len(content), 'MD5': hashlib.md5(content).hexdigest()})
        self.generated_names.append(name)
        return name

    def plate(self, item):
        name = item['Name']
        width, height = round(item['Width']), round(item['Height'])
        if name.endswith('_outer') and not name.startswith('tyre_'):
            role = 'frame'
        elif name.endswith('_inner'):
            role = 'inner'
        elif name.endswith('_header') or name == 'page_badge':
            role = 'header'
        elif name.endswith('_labelbg'):
            role = 'badge'
        elif name.startswith('rel_row_'):
            role = 'player' if name.endswith('_4') else 'row'
        else:
            role = 'tile'
        key = (width, height, role, item.get('BackgroundColor'))
        if key in self.cache:
            return self.cache[key]
        image = Image.new('RGBA', (width * SCALE, height * SCALE))
        draw = ImageDraw.Draw(image)
        cut = min(9 if role == 'frame' else 5, height / 4, width / 4)
        points = [(horizontal * SCALE, vertical * SCALE)
                  for horizontal, vertical in polygon_points(width - 1, height - 1, cut, 0.5)]
        mask = Image.new('L', image.size)
        ImageDraw.Draw(mask).polygon(points, fill=255)
        if role == 'frame':
            top_color, bottom_color = (36, 29, 20), (12, 11, 9)
            border, thickness = '#B78548', 1.5
        elif role in ('header', 'badge'):
            top_color, bottom_color = (42, 34, 24), (18, 15, 11)
            border, thickness = '#9C723D', 1
        elif role == 'player':
            top_color, bottom_color = (43, 34, 23), (26, 22, 17)
            border, thickness = '#AA8046', 1
        elif role == 'row':
            top_color = argb_to_rgba(item.get('BackgroundColor', '#FF15110D'))[:3]
            bottom_color = tuple(max(7, channel - 3) for channel in top_color)
            border, thickness = '#493725', 0.8
        else:
            top_color, bottom_color = (21, 18, 14), (12, 11, 9)
            border, thickness = '#705334' if role == 'tile' else '#44321F', 0.9
        for row in range(image.height):
            progress = min(1, row / max(1, image.height - 1))
            color = tuple(round(first + (second - first) * progress)
                          for first, second in zip(top_color, bottom_color))
            draw.line((0, row, image.width, row), fill=(*color, 255))
        image.putalpha(mask)
        draw.line(points + [points[0]], fill=border, width=round(thickness * SCALE), joint='curve')
        if role == 'frame':
            inset_points = [(horizontal * SCALE, vertical * SCALE)
                            for horizontal, vertical in polygon_points(width - 1, height - 1, max(2, cut - 2), 2.5)]
            draw.line(inset_points + [inset_points[0]], fill='#53402A', width=SCALE)
            for horizontal, vertical, direction in [(5, 5, 1), (width - 6, 5, -1),
                                                    (5, height - 6, 1), (width - 6, height - 6, -1)]:
                draw.line((horizontal * SCALE, vertical * SCALE,
                           (horizontal + direction * 5) * SCALE, vertical * SCALE),
                          fill='#D9AB65', width=SCALE)
        asset_name = 'retro_ui_plate_' + str(len(self.cache))
        self.cache[key] = self.add(asset_name, image)
        return self.cache[key]

    def dial(self, name, diameter, start_angle, divisions, major_interval, reserve=False):
        image = Image.new('RGBA', (diameter * SCALE, diameter * SCALE))
        draw = ImageDraw.Draw(image)
        center = diameter * SCALE / 2
        radius = center - 2 * SCALE
        draw.ellipse((center - radius, center - radius, center + radius, center + radius),
                     fill='#11100D', outline='#534E42', width=2 * SCALE)
        for inset, color, thickness in [(3, '#AD8045', 1), (6, '#312718', 1),
                                         (11, '#735737', 0.7), (28, '#342B1C', 0.8)]:
            inner_radius = radius - inset * SCALE
            draw.ellipse((center - inner_radius, center - inner_radius,
                          center + inner_radius, center + inner_radius),
                         outline=color, width=max(1, round(thickness * SCALE)))
        for division in range(divisions + 1):
            angle = math.radians(start_angle + division / divisions * 270)
            is_major = division % major_interval == 0
            if not is_major:
                continue
            outer_radius = radius - 12 * SCALE
            inner_radius = outer_radius - (7 if is_major else 3.5) * SCALE
            color = '#E9D6AA' if is_major else '#3D3427'
            if is_major and reserve and division <= divisions * 0.1:
                color = '#D84B3E'
            if is_major and not reserve and division >= divisions * 0.92:
                color = '#D84B3E'
            draw.line((center + math.cos(angle) * inner_radius,
                       center + math.sin(angle) * inner_radius,
                       center + math.cos(angle) * outer_radius,
                       center + math.sin(angle) * outer_radius),
                      fill=color, width=(2 if is_major else 1) * SCALE)
            if division % major_interval == 0:
                dot_radius = radius - 27 * SCALE
                horizontal = center + math.cos(angle) * dot_radius
                vertical = center + math.sin(angle) * dot_radius
                draw.ellipse((horizontal - SCALE / 2, vertical - SCALE / 2,
                              horizontal + SCALE / 2, vertical + SCALE / 2), fill='#9B7B4C')
        return self.add(name, image)

    def digital_dial_frames(self, prefix, diameter, start_angle, fuel=False):
        center = diameter * SCALE / 2
        outer_radius = center - 14 * SCALE
        inner_radius = outer_radius - (8 if fuel else 6.5) * SCALE
        segment_count, segment_gap = 40, 0.24
        span = 270 / segment_count
        segments = []
        for index in range(1, segment_count + 1):
            first = start_angle + (index - 1) * span + span * segment_gap / 2
            last = start_angle + index * span - span * segment_gap / 2
            angles = [math.radians(first + (last - first) * step / 5) for step in range(6)]
            points = [(center + math.cos(angle) * radius, center + math.sin(angle) * radius)
                      for radius, arc in [(outer_radius, angles), (inner_radius, reversed(angles))]
                      for angle in arc]
            threshold = math.floor(index * 100 / segment_count)
            color = AMBER if fuel or threshold < 70 else CYAN if threshold < 87 else '#FFFF6559'
            segments.append((points, threshold, color))
        for percent in range(101):
            image = Image.new('RGBA', (diameter * SCALE, diameter * SCALE))
            draw = ImageDraw.Draw(image)
            for points, threshold, color in segments:
                draw.polygon(points, fill=argb_to_rgba(color if percent >= threshold else '#FF2A231A'))
            self.add(prefix + '_' + str(percent), image)
        return prefix + '_0'

    def needle(self, name, ghost=False):
        size = 600
        image = Image.new('RGBA', (size, size))
        draw = ImageDraw.Draw(image)
        if ghost:
            draw.polygon([(300, 42), (304, 270), (303, 343), (297, 343), (296, 270)],
                         fill='#68B7D6')
            draw.ellipse((280, 280, 320, 320), outline='#68B7D6', width=3)
        else:
            draw.polygon([(300, 39), (309, 252), (308, 317), (304, 345),
                          (296, 345), (292, 317), (291, 252)], fill='#FFF0C6')
            glow = image.filter(ImageFilter.GaussianBlur(4))
            glow.putalpha(glow.getchannel('A').point(lambda value: value // 3))
            image = Image.alpha_composite(glow, image)
            draw = ImageDraw.Draw(image)
            draw.ellipse((276, 276, 324, 324), fill='#4F4029', outline='#D0AC67', width=4)
            draw.ellipse((286, 286, 314, 314), fill='#11100D', outline='#8E774E', width=2)
        return self.add(name, image)

    def save(self, destination):
        with zipfile.ZipFile(destination, 'w', zipfile.ZIP_DEFLATED) as archive:
            for name, content in self.contents.items():
                archive.writestr(name, content)


def restyle_header(items):
    by_name = {item['Name']: item for item in items}
    horizontal = 16
    for prefix, width in zip(('session', 'timeleft', 'position', 'lap', 'track', 'temps', 'grip', 'car'),
                             (88, 110, 76, 68, 136, 108, 52, 144)):
        label, value = by_name[prefix + '_label'], by_name[prefix + '_value']
        label.update(Left=horizontal, Width=width, Top=12, Height=13, FontSize=9, TextColor=SECONDARY)
        value.update(Left=horizontal, Width=width, Top=24, Height=24,
                     FontSize=11 if prefix == 'car' else 13 if prefix == 'track' else 17,
                     TextColor=PRIMARY, FontWeight='Bold')
        if prefix != 'car':
            items.append(new_item('RectangleItem', 'retro_ui_session_separator_' + prefix,
                                  horizontal + width + 2, 13, 0.8, 34,
                                  IsRectangleItem=True, BackgroundColor='#FF332B21'))
        horizontal += width + 5
    by_name['page_title'].update(FontSize=10, FontWeight='Bold', TextColor=PRIMARY)
    for item in items:
        if item['Name'].startswith('setup_') and item['Name'].endswith('_label'):
            item.update(FontSize=9, Height=12, Top=77, TextColor=SECONDARY)
        elif item['Name'].startswith('setup_') and item['Name'].endswith('_value'):
            item.update(FontSize=17, FontWeight='Bold', TextColor=PRIMARY)


def restyle_engineering(items, assets):
    by_name = {item['Name']: item for item in items}
    fuel_center = (130.5, 253)
    fuel_diameter = 190
    fuel_face = assets.dial('retro_ui_fuel_face', fuel_diameter, 135, 100, 25, reserve=True)
    outer = by_name['fuel_dial_outer']
    outer.update({'$type': MODEL_PREFIX + 'ImageItem' + MODEL_SUFFIX,
                  'Image': fuel_face, 'AutoSize': False, 'Left': 35.5, 'Top': 158,
                  'Width': fuel_diameter, 'Height': fuel_diameter, 'BackgroundColor': TRANSPARENT})
    add_digital_dial(items, outer, assets, 'fuel', 135,
                     'DataCorePlugin.Computed.Fuel_Percent', 200)
    by_name['fuel_dial_inner']['Visible'] = False
    by_name['fuel_arc'].update(Left=38.5, Top=161, Width=184, Height=184,
                               Visible=False, ArcThickness=4, SweepColor=CYAN,
                               SweepBackgroundColor='#FF282117')
    for name in ('fuel_needle', 'fuel_theory_needle'):
        by_name[name].update(Left=35.5, Top=158, Width=190, Height=190,
                             Image='retro_ui_ghost_needle' if 'theory' in name else 'retro_ui_needle')
    by_name['fuel_pct_label'].update(Left=85.5, Top=218, Width=90, Height=16, FontSize=10)
    by_name['fuel_liters'].update(Left=64.5, Top=263, Width=132, Height=40, FontSize=35, FontWeight='Bold')
    by_name['fuel_l_unit'].update(Left=98.5, Top=303, Width=64, Height=14, FontSize=9)
    by_name['fuel_margin_text'].update(Left=61.5, Top=323, Width=138, Height=14, FontSize=8)
    by_name['fuel_low_pulse'].update(Left=33.5, Top=156, Width=194, Height=194)
    by_name['fuel_low_text'].update(Left=77, Top=189, Width=107, Height=17)
    for value in (0, 25, 50, 75, 100):
        angle = math.radians(135 + value * 2.7)
        by_name['fuel_tick_' + str(value)].update(
            Left=fuel_center[0] + math.cos(angle) * 65 - 13,
            Top=fuel_center[1] + math.sin(angle) * 65 - 7,
            Width=26, Height=14, FontSize=10, TextColor=PRIMARY)
    rpm_outer = by_name['steer_outer']
    rpm_inner = by_name['steer_inner']
    rpm_face = assets.dial('retro_ui_rpm_face', 150, 165, 100, 101)
    rpm_outer.update({'$type': MODEL_PREFIX + 'ImageItem' + MODEL_SUFFIX,
                      'Image': rpm_face, 'AutoSize': False, 'Left': 615.5, 'Top': 157.5,
                      'Width': 150, 'Height': 150, 'BackgroundColor': TRANSPARENT})
    add_digital_dial(items, rpm_outer, assets, 'rpm', 165,
                     'DataCorePlugin.GameData.CarSettings_CurrentDisplayedRPMPercent', 50)
    rpm_inner['Visible'] = False
    by_name['rpm_arc'].update(Left=618.5, Top=160.5, Width=144, Height=144,
                              Visible=False, ArcThickness=4, SweepBackgroundColor='#FF282117')
    for name in ('rpm_needle', 'rpm_shift_ghost'):
        by_name[name].update(Left=615.5, Top=157.5, Width=150, Height=150,
                             Image='retro_ui_ghost_needle' if 'ghost' in name else 'retro_ui_needle')
    by_name['rpm_redline_pulse'].update(Left=613.5, Top=155.5, Width=154, Height=154)
    by_name['rpm_label'].update(Left=644, Top=198, Width=94, Height=13, FontSize=8)
    by_name['rpm_value'].update(Left=652, Top=239, Width=77, Height=31, FontSize=23, FontWeight='Bold')
    by_name['rpm_unit'].update(Left=650, Top=269, Width=82, Height=11, FontSize=8)
    for index in range(10):
        angle = math.radians(165 + index * 30)
        label = text_item('retro_ui_rpm_scale_' + str(index), '',
                          690.5 + math.cos(angle) * 50 - 10,
                          232.5 + math.sin(angle) * 50 - 6, 20, 12, 8)
        scale_expression = (
            "var rpm = retroFirstFiniteProperty(['DataCorePlugin.GameData.NewData.Rpms', 'Rpms']);\n"
            "var percent = Number($prop('DataCorePlugin.GameData.CarSettings_CurrentDisplayedRPMPercent'));\n"
            "var maximum = rpm > 0 && percent > 0 ? rpm * 100 / percent : retroFirstFiniteProperty("
            "['DataCorePlugin.GameData.NewData.MaxRpm', 'DataCorePlugin.GameData.MaxRpm', 'MaxRpm']);\n"
            "if (!isFinite(maximum) || maximum <= 0) maximum = NaN;\n")
        angle_expression = f'var angle = (165 + {index} * 1000 / maximum * 270) * Math.PI / 180;\n'
        def scale_binding(result):
            return {'Formula': {'JSExt': 3, 'Interpreter': 1,
                                'Expression': scale_expression + result}, 'Mode': 2}
        visibility = f'return isFinite(maximum) && maximum >= {index} * 1000;'
        label.update(MinimumRefreshIntervalMS=500)
        label['Bindings'] = {
            'Text': scale_binding(f"return isFinite(maximum) ? '{index}' : '';"),
            'Visible': scale_binding(visibility),
            'Left': scale_binding(angle_expression + 'return isFinite(angle) ? 690.5 + Math.cos(angle) * 50 - 10 : 680.5;'),
            'Top': scale_binding(angle_expression + 'return isFinite(angle) ? 232.5 + Math.sin(angle) * 50 - 6 : 226.5;')}
        items.append(label)
        marker = new_item('RectangleItem', 'retro_ui_rpm_mark_' + str(index),
                           690.5 + math.cos(angle) * 58 - 0.7,
                           232.5 + math.sin(angle) * 58 - 3.5, 1.4, 7,
                           IsRectangleItem=True, BackgroundColor=PRIMARY,
                           MinimumRefreshIntervalMS=500)
        marker['Bindings'] = {
            'Visible': scale_binding(visibility),
            'Left': scale_binding(angle_expression + 'return isFinite(angle) ? 690.5 + Math.cos(angle) * 58 - 0.7 : 689.8;'),
            'Top': scale_binding(angle_expression + 'return isFinite(angle) ? 232.5 + Math.sin(angle) * 58 - 3.5 : 229;'),
            'Rotation': scale_binding(f'return isFinite(maximum) ? 75 + {index} * 1000 / maximum * 270 : 75;')}
        items.append(marker)
    items.append(text_item('retro_ui_rpm_multiplier', '×1000', 665.5, 290, 50, 10, 7, SECONDARY))
    for corner in ('FL', 'FR', 'RL', 'RR'):
        by_name['tyre_' + corner + '_label'].update(FontWeight='Bold', TextColor=PRIMARY)
        for suffix in ('pressure', 'temp', 'wear'):
            by_name['tyre_' + corner + '_' + suffix]['FontWeight'] = 'Bold'
        by_name['tyre_' + corner + '_delta'].update(FontSize=11, FontWeight='Bold')
    by_name['throttle_value'].update(TextColor=CYAN, FontSize=13, FontWeight='Bold')
    by_name['brake_value'].update(TextColor='#FFD84B3E', FontSize=13, FontWeight='Bold')


def add_digital_dial(items, face, assets, role, start_angle, property_name, refresh_interval):
    prefix = 'retro_ui_' + role + '_digital'
    initial_image = assets.digital_dial_frames(prefix, face['Width'], start_angle, fuel=role == 'fuel')
    item = new_item('ImageItem', prefix, face['Left'], face['Top'], face['Width'], face['Height'],
                    Image=initial_image, AutoSize=False, MinimumRefreshIntervalMS=refresh_interval)
    item['Bindings'] = {'Image': {'Formula': {'JSExt': 3, 'Interpreter': 1,
        'Expression': f"var percent = Number($prop('{property_name}'));\n"
                      "if (!isFinite(percent)) percent = 0;\n"
                      "percent = Math.max(0, Math.min(100, percent));\n"
                      f"return '{prefix}_' + Math.floor(percent);"}, 'Mode': 2}}
    items.insert(items.index(face) + 1, item)


def segment_gauges(items):
    for gauge in list(items):
        if not gauge['$type'].endswith('LinearGaugeItem' + MODEL_SUFFIX):
            continue
        vertical = gauge.get('GaugeOrientation', 0) == 1
        gauge['BackgroundColor'] = '#FF252018'
        gauge['BorderStyle'] = {'BorderColor': '#FF66513A', 'BorderTop': 1,
                               'BorderBottom': 1, 'BorderLeft': 1, 'BorderRight': 1,
                               'RadiusTopLeft': 2, 'RadiusTopRight': 2,
                               'RadiusBottomLeft': 2, 'RadiusBottomRight': 2}
        count = 12 if vertical else 10
        for separator in range(1, count):
            horizontal = gauge['Left'] if vertical else gauge['Left'] + gauge['Width'] * separator / count
            top = gauge['Top'] + gauge['Height'] * separator / count if vertical else gauge['Top']
            width = gauge['Width'] if vertical else 0.9
            height = 1.5 if vertical else gauge['Height']
            items.append(new_item('RectangleItem', 'retro_ui_segment_' + gauge['Name'] + '_' + str(separator),
                                  horizontal, top, width, height, IsRectangleItem=True,
                                  BackgroundColor='#FF1D1912'))


def restyle_startup(items, assets):
    plate = new_item('RectangleItem', 'retro_ui_startup_plate', 34, 126, 784, 350,
                     IsRectangleItem=True, BackgroundColor='#FF15110D')
    plate.update({'$type': MODEL_PREFIX + 'ImageItem' + MODEL_SUFFIX,
                  'Image': assets.plate(plate), 'AutoSize': False, 'BackgroundColor': TRANSPARENT})
    plate.pop('IsRectangleItem', None)
    items.insert(0, plate)
    by_name = {item['Name']: item for item in items}
    by_name['startup_title'].update(Top=224, FontSize=31, FontWeight='Bold', TextColor=PRIMARY)
    by_name['startup_subtitle'].update(Top=284, FontSize=13, TextColor=SECONDARY)
    by_name['startup_version'].update(Text='v2.6.1 · RETRO UI STYLE', Top=420, TextColor=AMBER)
    items.append(new_item('RectangleItem', 'retro_ui_startup_rule', 90, 332, 672, 1,
                          IsRectangleItem=True, BackgroundColor='#FF76542C'))
    for index, label in enumerate(('ENGINEERING', 'STRATEGY', 'AWARENESS')):
        items.append(text_item('retro_ui_startup_label_' + str(index), label,
                               130 + index * 210, 355, 172, 30, 12, AMBER))


def verify(original, dashboard, source_directory, destination_directory, assets):
    visual_fields = {'$type', 'IsRectangleItem', 'IsTextItem', 'Image', 'AutoSize',
                     'Font', 'FontSize', 'FontWeight', 'TextColor', 'BackgroundColor',
                     'BorderStyle', 'FillColor', 'EllipseColor', 'EllipseThickness',
                     'Left', 'Top', 'Width', 'Height', 'Visible', 'ArcThickness',
                     'SweepColor', 'SweepBackgroundColor', 'GaugeColor', 'AlternateGaugeColor',
                     'PlayerStyle', 'OpponentStyle', 'PlayerTextColor', 'OpponentTextColor',
                     'PlayerFontSize', 'OpponentFontSize', 'PlayerFontWeight', 'OpponentFontWeight',
                     'TrackColor', 'TrackBorderColor', 'AlternateTrackSectorColor', 'Text'}
    for key in ('Id', 'BaseWidth', 'BaseHeight', 'Variables', 'ShowOnScreenControls',
                'EnableOnDashboardMessaging', 'UseStrictJSIsolation'):
        assert original.get(key) == dashboard.get(key), key
    assert len(original['Screens']) == len(dashboard['Screens']) == 4
    report = []
    for original_screen, screen in zip(original['Screens'], dashboard['Screens']):
        for key, value in original_screen.items():
            if key != 'Items':
                assert screen[key] == value, (screen['Name'], key)
        original_items = {item['Name']: item for item in walk_items(original_screen['Items'])}
        updated_items = list(walk_items(screen['Items']))
        updated_by_name = {item['Name']: item for item in updated_items}
        assert len(updated_by_name) == len(updated_items), 'Duplicate item names'
        bound_count = 0
        for name, original_item in original_items.items():
            assert name in updated_by_name, ('Missing component', name)
            updated_item = updated_by_name[name]
            assert original_item.get('Bindings') == updated_item.get('Bindings'), ('Changed bindings', name)
            for key, value in original_item.items():
                if key not in visual_fields and key != 'Childrens':
                    assert updated_item.get(key) == value, ('Changed functional property', name, key)
            if original_item.get('Bindings'):
                bound_count += len(original_item['Bindings'])
        for item in updated_items:
            if screen['Name'] == 'Engineering' and item['Name'] in ('fuel_arc', 'rpm_arc'):
                assert item['Visible'] is False, ('Duplicate continuous dial fill', item['Name'])
            if item.get('Image'):
                assert item['Image'] + '.png' in assets.contents or item['Image'] + '.jpg' in assets.contents
            if item['Name'].startswith('retro_ui_') and not item.get('Childrens'):
                assert item['Left'] >= 0 and item['Top'] >= 0, item['Name']
                assert item['Left'] + item['Width'] <= dashboard['BaseWidth'] + 0.1, item['Name']
                assert item['Top'] + item['Height'] <= dashboard['BaseHeight'] + 0.1, item['Name']
        report.append({'screen': screen['Name'], 'originalComponents': len(original_items),
                       'updatedComponents': len(updated_items), 'preservedBindings': bound_count})
    for source_file in (source_directory / 'JavascriptExtensions').glob('*'):
        if source_file.is_file():
            assert source_file.read_bytes() == (destination_directory / 'JavascriptExtensions' / source_file.name).read_bytes()
    assert dashboard['Metadata']['Width'] == dashboard['BaseWidth'] == 852
    assert dashboard['Metadata']['Height'] == dashboard['BaseHeight'] == 639
    return report


def update_previews(destination, preview_directory):
    for suffix, screen_name in [('', 'engineering'), ('.00', 'startup'),
                               ('.01', 'engineering'), ('.02', 'strategy'),
                               ('.03', 'awareness')]:
        preview_path = Path(str(destination) + suffix + '.png')
        with Image.open(preview_path) as original_preview:
            preview_size = original_preview.size
        with Image.open(preview_directory / (screen_name + '.png')) as capture:
            if capture.size != (852, 639):
                raise ValueError('Preview captures must use the native 852 x 639 resolution.')
            capture.convert('RGB').resize(preview_size, Image.Resampling.LANCZOS).save(preview_path)


def build(source_path, output_directory, preview_directory=None):
    original = json.loads(source_path.read_text(encoding='utf-8-sig'))
    if any(image['Name'].startswith('retro_ui_') for image in original['Images']):
        raise ValueError('Use the original dashboard from the backup as --source, not an already restyled dashboard.')
    dashboard = copy.deepcopy(original)
    output_directory.mkdir(parents=True, exist_ok=True)
    destination = output_directory / source_path.name
    assets = AssetLibrary(dashboard, Path(str(source_path) + '.ressources'))
    assets.needle('retro_ui_needle')
    assets.needle('retro_ui_ghost_needle', ghost=True)
    for screen in dashboard['Screens']:
        items = screen['Items'][0]['Childrens']
        if screen['Name'] == 'Startup':
            restyle_startup(items, assets)
            continue
        restyle_header(items)
        for item in items:
            name = item['Name']
            if item.get('IsTextItem'):
                item['Font'] = 'Consolas'
                if item.get('FontSize', 0) < 8:
                    item['FontSize'] = 8
                if item.get('TextColor') == '#FF987A4C':
                    item['TextColor'] = SECONDARY
                if name.endswith('_title') and name != 'page_title':
                    available_size = item['Width'] / max(1, len(item.get('Text', ''))) / 0.63
                    item.update(FontSize=min(14, math.floor(available_size * 2) / 2),
                                FontWeight='Bold', TextColor=PRIMARY)
                if name.endswith('_code'):
                    item['TextColor'] = SECONDARY
                    if name == 'R01_code':
                        item.update(Left=362, Width=35)
            if '_screw_' in name:
                item['Visible'] = False
            if item['$type'].endswith('RectangleItem' + MODEL_SUFFIX) and item.get('BorderStyle') and not item.get('Bindings'):
                image_name = assets.plate(item)
                item.update({'$type': MODEL_PREFIX + 'ImageItem' + MODEL_SUFFIX,
                             'Image': image_name, 'AutoSize': False, 'BackgroundColor': TRANSPARENT})
                item.pop('IsRectangleItem', None)
                item.pop('BorderStyle', None)
            elif item.get('BorderStyle') and item.get('Bindings') and name.startswith('tyre_'):
                item['BorderStyle'].update(BorderColor='#FF796741', RadiusTopLeft=4, RadiusTopRight=4,
                                           RadiusBottomLeft=4, RadiusBottomRight=4)
            if 'LeaderboardOpponent' in item['$type']:
                item.update(TextColor=PRIMARY if item.get('FontSize', 0) >= 11 else SECONDARY,
                            PlayerTextColor=AMBER, OpponentTextColor=PRIMARY if item.get('FontSize', 0) >= 11 else SECONDARY)
                if 'PlayerStyle' in item:
                    item['PlayerStyle']['TextColor'] = AMBER
                    item['OpponentStyle']['TextColor'] = item['OpponentTextColor']
            if item['$type'].endswith('RadarItem' + MODEL_SUFFIX):
                item['OpponentStyle']['DotColor'] = CYAN
            if item['$type'].endswith('GeneratedStaticMapItem' + MODEL_SUFFIX):
                item.update(TrackColor='#FF756044', TrackBorderColor='#FFA58852')
        if screen['Name'] == 'Engineering':
            restyle_engineering(items, assets)
        segment_gauges(items)
    dashboard['Metadata']['Description'] = (
        'Retro UI style for all four console screens: chamfered graphite instruments, '
        'illuminated ivory needles, digital fuel/RPM divisions, adaptive RPM graduations and segmented gauges. '
        'Original telemetry, reference needles, flags, radar, map and controls preserved.')
    for source_file in source_path.parent.iterdir():
        if source_file.is_file() and source_file.name != source_path.name and not source_file.name.endswith('.ressources'):
            (output_directory / source_file.name).write_bytes(source_file.read_bytes())
        elif source_file.is_dir() and source_file.name in ('JavascriptExtensions', 'Videos'):
            import shutil
            shutil.copytree(source_file, output_directory / source_file.name, dirs_exist_ok=True)
    assets.save(Path(str(destination) + '.ressources'))
    destination.write_text(json.dumps(dashboard, ensure_ascii=False, indent=2), encoding='utf-8')
    Path(str(destination) + '.metadata').write_text(json.dumps(dashboard['Metadata'], ensure_ascii=False, indent=2), encoding='utf-8')
    report = {'source': str(source_path), 'dashboard': str(destination),
              'resolution': [852, 639], 'generatedAssets': len(assets.generated_names),
              'screens': verify(original, dashboard, source_path.parent, output_directory, assets)}
    if preview_directory is not None:
        update_previews(destination, preview_directory)
        report['previewDirectory'] = str(preview_directory)
    (output_directory.parent / 'verification.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output-directory', type=Path, required=True)
    parser.add_argument('--preview-directory', type=Path)
    arguments = parser.parse_args()
    build(arguments.source.resolve(), arguments.output_directory.resolve(),
          arguments.preview_directory.resolve() if arguments.preview_directory else None)


if __name__ == '__main__':
    main()
