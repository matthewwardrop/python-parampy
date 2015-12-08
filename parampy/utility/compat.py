import sys

def isstr(obj):
    return True

def strrep(obj):
    if sys.version_info[0] < 3:
        return unicode(obj).encode('utf-8')
    return obj.__unicode__()

if sys.version_info[0] >= 3:
    str_types = (str,)
else:
    str_types = (str,unicode)

class UnicodeMixin(object):

    """Mixin class to handle defining the proper __str__/__unicode__
      methods in Python 2 or 3."""

    if sys.version_info[0] >= 3: # Python 3
        def __str__(self):
            return self.__unicode__()
    else:  # Python 2
        def __str__(self):
            return self.__unicode__().encode('utf8')