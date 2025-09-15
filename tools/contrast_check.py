#!/usr/bin/env python3
# Simple WCAG contrast checker for the Tiercade design tokens.
# Reads a hard-coded set of hex tokens (extracted from DesignTokens.swift) and reports contrast ratios.

import math

TOKENS = {
    'bg_light': '#FFFFFF',
    'bg_dark': '#0B0F14',
    'surface_light': '#F8FAFC',
    'surface_dark': '#0F141A',
    'surfHi_light': '#00000008',
    'surfHi_dark': '#FFFFFF14',
    'text_light': '#111827',
    'text_dark': '#E8EDF2',
    'textDim_light': '#6B7280',
    'textDim_dark': '#FFFFFFB8',
    'brand': '#3B82F6',
    'tier_S': '#E11D48',
    'tier_A': '#F59E0B',
    'tier_B': '#22C55E',
    'tier_C': '#06B6D4',
    'tier_D': '#3B82F6',
    'tier_F': '#6B7280',
}

def hex_to_rgb(hexstr):
    s = hexstr.strip().lstrip('#')
    if len(s) == 8: # ARGB or RRGGBBAA? assume RRGGBBAA
        s = s[:6]
    r = int(s[0:2], 16) / 255.0
    g = int(s[2:4], 16) / 255.0
    b = int(s[4:6], 16) / 255.0
    return (r,g,b)

def luminance(rgb):
    def chan(c):
        return c/12.92 if c <= 0.03928 else ((c+0.055)/1.055) ** 2.4
    r,g,b = rgb
    return 0.2126*chan(r) + 0.7152*chan(g) + 0.0722*chan(b)

def contrast(a_hex, b_hex):
    la = luminance(hex_to_rgb(a_hex))
    lb = luminance(hex_to_rgb(b_hex))
    L1 = max(la, lb)
    L2 = min(la, lb)
    return (L1 + 0.05) / (L2 + 0.05)

PAIRS = [
    ('text_light', 'surface_light'),
    ('text_light', 'bg_light'),
    ('textDim_light', 'surface_light'),
    ('brand', 'surface_light'),
    ('text_dark', 'surface_dark'),
    ('text_dark', 'bg_dark'),
    ('textDim_dark', 'surface_dark'),
    ('brand', 'surface_dark'),
    ('brand', 'bg_light'),
    ('brand', 'bg_dark'),
]

TIER_KEYS = ['tier_S','tier_A','tier_B','tier_C','tier_D','tier_F']

def report_tiers():
    print('\nTier color sweep vs surfaces:')
    print('Tier, Target, Contrast, AA(normal), AA(large)')
    for t in TIER_KEYS:
        for target_key in ['surface_light','bg_light','surface_dark','bg_dark']:
            c = contrast(TOKENS[t], TOKENS[target_key])
            aa_norm = 'PASS' if c >= 4.5 else 'FAIL'
            aa_large = 'PASS' if c >= 3.0 else 'FAIL'
            print(f"{t} on {target_key}, {c:.2f}, {aa_norm}, {aa_large}")

def report():
    print('WCAG contrast report for Tiercade tokens')
    print('Pair, Contrast, AA(normal), AA(large), AAA(normal), AAA(large)')
    for a,b in PAIRS:
        ca = TOKENS[a]
        cb = TOKENS[b]
        c = contrast(ca, cb)
        aa_norm = 'PASS' if c >= 4.5 else 'FAIL'
        aa_large = 'PASS' if c >= 3.0 else 'FAIL'
        aaa_norm = 'PASS' if c >= 7.0 else 'FAIL'
        aaa_large = 'PASS' if c >= 4.5 else 'FAIL'
        print(f'{a} on {b}, {c:.2f}, {aa_norm}, {aa_large}, {aaa_norm}, {aaa_large}')

if __name__ == '__main__':
    report()
    report_tiers()
