select distinct
[Original UPC], --REPLACE THIS COLUMN to whichever column you are having a problem with. This should list our what if there are extra spacing/ tabs in your specified column. 
space             = iif(charindex(char(32), [Original UPC]) > 0, 1, 0),
horizontal_tab    = iif(charindex(char(9), [Original UPC]) > 0, 1, 0),
vertical_tab      = iif(charindex(char(11), [Original UPC]) > 0, 1, 0),
backspace         = iif(charindex(char(8), [Original UPC]) > 0, 1, 0),
carriage_return   = iif(charindex(char(13), [Original UPC]) > 0, 1, 0),
newline           = iif(charindex(char(10), [Original UPC]) > 0, 1, 0),
formfeed          = iif(charindex(char(12), [Original UPC]) > 0, 1, 0),
nonbreakingspace  = iif(charindex(char(255), [Original UPC]) > 0, 1, 0)
from [Inflation_Matches];


update [Inflation_Matches]
set [Original UPC] = REPLACE(REPLACE([UPC], CHAR(10), ''), CHAR(13), '') --Change the CHAR(X) based on your results from the query. 
