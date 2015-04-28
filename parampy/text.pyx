#!/usr/bin/env python
import sys
COLOURS = (
    'BLACK', 'RED', 'GREEN', 'YELLOW',
    'BLUE', 'MAGENTA', 'CYAN', 'WHITE'
)


def colour_text(text, colour_name='WHITE', bold=False):
    if colour_name in COLOURS:
        return '\033[{0};{1}m{2}\033[0m'.format(
            int(bold), COLOURS.index(colour_name) + 30, text)
    sys.stderr.write('ERROR: "{0}" is not a valid colour.\n'.format(colour_name))
    sys.stderr.write('VALID COLOURS: {0}.\n'.format(', '.join(COLOURS)))


# TESTS
if __name__ == '__main__':
    for bold in (False, True):
        for colour_name in COLOURS:
            print colour_text('Example of {0}'.format(colour_name), colour_name, bold)
    print
    # test error handling
    colour_text('TEST', 'SILVER')

