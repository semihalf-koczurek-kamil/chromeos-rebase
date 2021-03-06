# -*- coding: utf-8 -*-"
from __future__ import print_function
import sqlite3
import os
import re
import time
from config import rebasedb

def NOW():
  return int(time.time())

workdir = os.getcwd()

conn = sqlite3.connect(rebasedb)
# conn.text_factory = str

c = conn.cursor()
c2 = conn.cursor()

rp = re.compile('Revert "(.*)"')

def mark_disposition(db, sha, disposition, reason, revert_sha):
    '''Mark sha for given disposition. If available, add revert_sha into dsha.'''

    c = db.cursor()

    print("    Marking %s for %s (%s)" % (sha, disposition, reason))

    cmd='UPDATE commits SET disposition="%s", reason="%s", updated="%d"' % (disposition, reason, NOW())
    if revert_sha:
        cmd += ', dsha="%s"' % revert_sha
    cmd += ' where sha="%s"' % sha

    print("  SQL: %s" % cmd)

    c.execute(cmd)


# date:
#         git show --format="%ct" -s ${sha}
# subject:
#        git show --format="%s" -s ${sha}
# file list:
#        git show --name-only --format="" ${sha}

# Insert a row of data
# c.execute("INSERT INTO commits VALUES (1489758183,sha,subject)")
# c.execute("INSERT INTO files VALUES (sha,filename)")
# sha and filename must be in ' '

c.execute("select committed, sha, disposition, subject from commits")
for (committed, sha, disposition, desc) in c.fetchall():
  # If the patch has already been dropped, don't bother any further
  if disposition == "drop":
    continue
  m = rp.search(desc)
  if m:
    ndesc = m.group(1)
    print("Found revert : '%s' (%s)" % (desc.replace("'", "''"), sha))
    ndesc = ndesc.replace("'", "''")
    c2.execute("select committed, sha from commits where subject is '%s'"
               % ndesc)
    # Search for commit closest to the revert in the past
    # (There may be multiple if the revert was repeated)
    revert_committed = None
    revert_sha = None
    for (_committed, _sha,) in c2.fetchall():
      if _committed < committed:
        if not revert_sha or revert_committed < _committed:
          revert_committed = _committed
          revert_sha = _sha

    # <sha> is the revert of <revert_sha>. Mark both as reverted.
    if revert_sha:
      mark_disposition(conn, revert_sha, 'drop', 'reverted', sha)
      mark_disposition(conn, sha, 'drop', 'reverted', revert_sha)
      # Now check if we can find a FIXUP: of <revert_sha>. It must
      # have been committed between <revert_sha> and <sha>.
      fdesc = "FIXUP: %s" % ndesc
      c2.execute("select committed, sha from commits where subject is '%s'" % fdesc)
      for (_committed, _sha,) in c2.fetchall():
          if _committed <= committed and _committed >= revert_committed:
              mark_disposition(conn, _sha, 'drop', "fixup/reverted", revert_sha)
    else:
      mark_disposition(conn, sha, 'pick', 'revisit', None)
      print("    No matching commit found")

conn.commit()

# We can also close the connection if we are done with it.
# Just be sure any changes have been committed or they will be lost.
conn.close()

# c.execute('SELECT * FROM commits')
# c.fetchone() -> read one result
#
# for entry in c.execute(SELECT * FROM commits ORDER BY date'):
#     print entry
#     print entry.sha
#     print entry.subject
