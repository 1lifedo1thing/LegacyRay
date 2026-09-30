"""previews of the classic finish, in russian, with the geometry of
LRConsoleScreen, LRStationCells, LRPlateCell and LRTableScreen:
    python3 scripts/design/classic_mockup.py
writes docs/preview-classic-iphone.png and docs/preview-classic-ipad.png"""
import os
import sys
import cairo

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from classic import *  # noqa: F401,F403,E402

DOCS = os.path.normpath(os.path.join(HERE, '..', '..', 'docs'))
WHITE = (1, 1, 1, 1)


def console_geometry(W, H):
    """LRConsoleLayoutFor"""
    if W < 500:
        R = 70 if H < 440 else 78
        side = R * 2 + 38
        cy = 30 + side / 2 + (10 if H >= 440 else 0)
        sy = cy + side / 2 + 14
        cw = min(W - 20, 420)
        cardy = max(sy + 70, H - 62 - 12)
    else:
        R = min(110, max(80, min(W, H) * 0.16))
        side = R * 2 + 38
        cy = max(side / 2 + 30, H * 0.36)
        sy = cy + side / 2 + 18
        cw = min(W - 60, 420)
        cardy = min(sy + 96, H - 62 - 20)
    return R, cy, sy, cw, cardy


def main_screen(cr, x, y, w, h, state='on', pad=False):
    """the console; y is the top of the navigation bar"""
    top = y + 44
    body = h - 44
    R, cy, sy, cw, cardy = console_geometry(w, body)
    main_background(cr, x, top, w, body, top + cy)
    if pad:
        nav_bar(cr, x, y, w, 'LegacyRay', left=('text', 'Проверка'), right=('glyph', 'gear'))
    else:
        nav_bar(cr, x, y, w, 'LegacyRay', left=('glyph', 'plus'), right=('glyph', 'gear'))
    power_button(cr, x + w / 2, top + cy, R, state)
    label = {'on': 'Подключено', 'off': 'Не подключено', 'tuning': 'Подключение…',
             'error': 'Не удалось подключиться'}[state]
    text(cr, label, x + w / 2, top + sy + 21, 20, WHITE, bold=True, align='center', shadow=(0, 0, 0, 0.8), dy=1)
    sub = {'on': '01:24:07    ↓ 318 MB    ↑ 12.4 MB', 'off': 'Нажмите кнопку, чтобы подключиться.',
           'tuning': 'Amsterdam', 'error': 'Сервер не ответил.'}[state]
    text(cr, sub, x + w / 2, top + sy + 44, 14, hexc('#A4A8AE'), align='center', shadow=(0, 0, 0, 0.8), dy=1)
    server_card(cr, x + (w - cw) / 2, top + cardy, cw, 59, 'nl', 'Amsterdam', 'VLESS · Reality · XHTTP',
                '48 ms')


def wrap(cr, s, size, width, bold=False):
    cr.select_font_face(FONT, cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD if bold else cairo.FONT_WEIGHT_NORMAL)
    cr.set_font_size(size)
    lines, line = [], ''
    for word in s.split(' '):
        t = (line + ' ' + word).strip()
        if cr.text_extents(t).x_advance > width and line:
            lines.append(line)
            line = word
        else:
            line = t
    lines.append(line)
    return lines


def grouped(cr, x, y, w, sections, margin=10):
    """LRTableScreen: captions, rows (dict: title, detail, sub, kind, on)"""
    for header, rows, foot in sections:
        if header:
            y += 36
            section_header(cr, header, x + margin + 10, y - 9)
        else:
            y += 14
        for i, row in enumerate(rows):
            n = len(rows)
            pos = 'single' if n == 1 else ('top' if i == 0 else ('bottom' if i == n - 1 else 'middle'))
            left, right = x + margin + 10, x + w - margin - 10
            kind = row.get('kind', 'value')
            sub = row.get('sub')
            sublines = wrap(cr, sub, 13, right - left - (20 if kind == 'check' else 0)) if sub else []
            rh = 44 if not sub else max(44, 32 + 16 * len(sublines) + 8)
            group_cell(cr, x + margin, y, w - margin * 2, rh, pos)
            ty = y + (8 + 17 if sub else rh / 2 + 6)
            if kind == 'button':
                text(cr, row['title'], x + w / 2, y + rh / 2 + 6, 17, DETAIL, bold=True, align='center')
            elif kind == 'switch':
                text(cr, row['title'], left, ty, 17, INK, bold=True)
                switch(cr, right - 79 + 4, y + (rh - 27) / 2, row.get('on', True), on_text='ВКЛ', off_text='ВЫКЛ')
            elif kind == 'check':
                on = row.get('on')
                text(cr, row['title'], left, ty, 17, DETAIL if on else INK, bold=True, maxw=right - left - 24, fit=13)
                if on:
                    checkmark(cr, right - 14, y + rh / 2)
            else:
                r2 = right
                if row.get('chevron', True):
                    chevron(cr, right - 3, y + rh / 2)
                    r2 -= 14
                if row.get('detail'):
                    text(cr, row['detail'], r2, ty, 16, DETAIL, align='right')
                text(cr, row['title'], left, ty, 17, INK, bold=True, maxw=(right - left) * 0.6)
            for k, line in enumerate(sublines):
                text(cr, line, left, y + 45 + k * 16, 13, MUTED)
            y += rh
        if foot:
            lines = wrap(cr, foot, 15, w - 2 * (margin + 10))
            y += 8
            for k, line in enumerate(lines):
                text(cr, line, x + w / 2, y + 15 + k * 19, 15, HEADER, align='center', shadow=WHITE, dy=1)
            y += len(lines) * 19 + 8
    return y


def station_list(cr, x, y, w, margin=10):
    """LRStationsScreen with LRStationCell rows and LRPlateHeaderCell captions"""
    groups = [
        ('Nebula VPN', '82% · 12 дн', [
            ('nl', 'Amsterdam', 'VLESS · Reality', '48 ms', GOOD, True),
            ('de', 'Frankfurt', 'VLESS · XHTTP', '61 ms', GOOD, False),
            ('fi', 'Helsinki', 'VLESS · gRPC', '97 ms', GOOD, False),
            ('us', 'New York', 'Trojan · TLS', '144 ms', GOOD, False),
            ('jp', 'Tokyo', 'VLESS · WS', 'нет сигнала', BAD, False)]),
        ('Вручную', '2 станции', [
            ('se', 'Stockholm', 'Shadowsocks · 2022', None, None, False),
            (None, 'Домашний роутер', 'AmneziaWG', None, None, False)]),
    ]
    for title, meta, rows in groups:
        mid = y + 44 - 16
        text(cr, title, x + margin + 9, mid + 6, 17, HEADER, bold=True, shadow=WHITE, dy=1)
        right = x + w - margin - 9
        cr.save()
        cr.set_source_rgba(*HEADER)
        cr.set_line_width(2)
        cr.move_to(right - 8, mid - 2)
        cr.line_to(right - 4, mid + 2)
        cr.line_to(right, mid - 2)
        cr.stroke()
        cr.restore()
        text(cr, meta, right - 16, mid + 5, 14, HEADER, align='right', shadow=WHITE, dy=1)
        y += 44
        for i, (code, name, detail, ping, col, sel) in enumerate(rows):
            n = len(rows)
            pos = 'single' if n == 1 else ('top' if i == 0 else ('bottom' if i == n - 1 else 'middle'))
            rh = 56
            group_cell(cr, x + margin, y, w - margin * 2, rh, pos)
            midy = y + (rh - (1 if pos in ('bottom', 'single') else 0)) / 2
            cx = x + margin + 10
            if sel:
                checkmark(cr, cx, midy)
            if code:
                flag(cr, code, cx + 22, midy - 12, 24)
            tx = cx + 56
            rowr = x + w - margin
            detail_disclosure(cr, rowr - 22, midy)
            rr = rowr - 40
            pw = text(cr, ping, rr, midy + 5, 14, col, align='right') + 8 if ping else 0
            text(cr, name, tx, midy - 3, 17, DETAIL if sel else INK, bold=True, maxw=rr - pw - tx)
            text(cr, detail, tx, midy + 15, 13, MUTED, maxw=rr - pw - tx)
            y += rh
    return y


def sites_list(cr, x, y, w):
    return grouped(cr, x, y, w, [
        ('Режим', [dict(kind='check', title='Все сайты через VPN, кроме списка', on=True),
                   dict(kind='check', title='Только сайты из списка через VPN', on=False)],
         'Изменение списка перезапускает подключённый туннель.'),
        ('Мимо VPN', [dict(title='youtube.com', sub='Головной домен · *.youtube.com/*', chevron=False),
                      dict(title='music.yandex.ru', sub='Конкретный домен · music.yandex.ru/*', chevron=False),
                      dict(title='госуслуги.рф', sub='Головной домен · *.госуслуги.рф/*', chevron=False)], None),
        (None, [dict(kind='button', title='Добавить сайт')], None),
    ])


def add_site(cr, x, y, w):
    group_cell(cr, x + 10, y + 14, w - 20, 44, 'single')
    text(cr, 'music.youtube.com', x + 22, y + 42, 17, INK)
    return grouped(cr, x, y + 58, w, [
        ('Совпадение', [
            dict(kind='check', title='Конкретный домен', on=False,
                 sub='Только music.youtube.com/* — без поддоменов'),
            dict(kind='check', title='Головной домен', on=True,
                 sub='youtube.com/* и *.youtube.com/* — со всеми поддоменами')],
         'Маршрутизация видит имя сайта, а не страницу, поэтому правило охватывает все страницы того, что совпало.')])


def iphone(path):
    W, H, S, GAP = 320, 480, 2, 20
    screens = []

    def console(cr):
        main_screen(cr, 0, 20, W, H - 20, 'on')
    screens.append(console)

    def stations(cr):
        pinstripes(cr, 0, 64, W, H - 64)
        station_list(cr, 0, 64, W)
        nav_bar(cr, 0, 20, W, 'Станции', left=('text', 'Назад', 'back'), right=('glyph', 'plus'),
                extra=('glyph', 'dots'))
    screens.append(stations)

    def settings(cr):
        pinstripes(cr, 0, 64, W, H - 64)
        grouped(cr, 0, 64, W, [
            ('Подключение', [dict(kind='switch', title='Переподключаться', on=True),
                             dict(kind='switch', title='Kill switch', on=False)], None),
            ('Маршрутизация', [dict(title='Правила', detail='Вкл · 14'),
                               dict(title='Сайты', detail='Всё, кроме списка')], None),
            ('Оформление', [dict(title='Тема', detail='Автоматически'),
                            dict(title='Язык', detail='Русский')], None),
        ])
        nav_bar(cr, 0, 20, W, 'Настройки', left=('text', 'Готово', 'done'))
    screens.append(settings)

    def sites(cr):
        pinstripes(cr, 0, 64, W, H - 64)
        sites_list(cr, 0, 64, W)
        nav_bar(cr, 0, 20, W, 'Сайты', left=('text', 'Назад', 'back'))
    screens.append(sites)

    def add(cr):
        pinstripes(cr, 0, 64, W, H - 64)
        add_site(cr, 0, 64, W)
        nav_bar(cr, 0, 20, W, 'Новый сайт', left=('text', 'Назад', 'back'), right=('text', 'Добавить', 'done'))
    screens.append(add)

    n = len(screens)
    surf = cairo.ImageSurface(cairo.FORMAT_RGB24, (W * n + GAP * (n - 1)) * S, H * S)
    cr = cairo.Context(surf)
    cr.scale(S, S)
    cr.set_source_rgb(1, 1, 1)
    cr.paint()
    for i, fn in enumerate(screens):
        cr.save()
        cr.translate(i * (W + GAP), 0)
        cr.rectangle(0, 0, W, H)
        cr.clip()
        status_bar(cr, W)
        fn(cr)
        cr.restore()
    surf.write_to_png(path)


def ipad(path, W=1024, H=768):
    surf = cairo.ImageSurface(cairo.FORMAT_RGB24, W, H)
    cr = cairo.Context(surf)
    status_bar(cr, W)
    lw = 320
    pinstripes(cr, 0, 64, lw, H - 64)
    station_list(cr, 0, 64, lw)
    nav_bar(cr, 0, 20, lw, 'Станции', left=('glyph', 'dots'), right=('glyph', 'plus'))
    cr.set_source_rgb(0, 0, 0)
    cr.rectangle(lw, 20, 1, H - 20)
    cr.fill()
    main_screen(cr, lw + 1, 20, W - lw - 1, H - 20, 'on', pad=True)
    surf.write_to_png(path)


if __name__ == '__main__':
    os.makedirs(DOCS, exist_ok=True)
    iphone(os.path.join(DOCS, 'preview-classic-iphone.png'))
    ipad(os.path.join(DOCS, 'preview-classic-ipad.png'))
    print('previews written to', DOCS)
