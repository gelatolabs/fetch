<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" tiledversion="1.11.2" name="tiles" tilewidth="16" tileheight="16" tilecount="2" columns="0">
 <editorsettings>
  <export target="tiles.lua" format="lua"/>
 </editorsettings>
 <grid orientation="orthogonal" width="1" height="1"/>
 <tile id="1">
  <image source="../tiles/brown.png" width="16" height="16"/>
 </tile>
 <tile id="14">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="0.5"/>
  </properties>
  <image source="../tiles/rock.png" width="16" height="16"/>
 </tile>
</tileset>
