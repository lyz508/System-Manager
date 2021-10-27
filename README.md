# System Manager
```
OS environment: FreeBSD 13.0-RELEASE-p4 
```
- With dialog to optimize representation of informations.
- Can easily monitor and trace actions of users.
- Lock and unlock user
- Send message to paticular or all users.
- Export Information as files.

## Architecture
![](media/Action-flow.png)
> whole architecture
> several functions are provided

## Code Structure
- tmp files
  - for temporary IO and caches.
- Functions
  - Main event loop
  - Provided functions.
  - Interrupts processor.

## Demo Image
![](media/System-Info-Panel.png)
> entry

### Announcement
![](media/Announcement-panel.png)
> selecting user to talk, or broadcst to every loginned users


![](media/Typing-Message.png)
> for typing messages

### Action Panel
![](media/Action-Panel.png)
> list all loginable users, highlight for logged in users

### User List
![](media/Actions.png)
> probable actions to a user

### Port Info
![](media/Port-Info.png)
> user login port info
