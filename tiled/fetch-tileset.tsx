<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" tiledversion="1.11.2" name="fetch-tileset" tilewidth="16" tileheight="16" tilecount="400" columns="20">
 <editorsettings>
  <export target="fetch-tileset.lua" format="lua"/>
 </editorsettings>
 <image source="../tiles/fetch-tileset.png" width="320" height="320"/>
 <tile id="0">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="is_water" type="bool" value="true"/>
  </properties>
 </tile>
 <tile id="100" type="ground::grass"/>
 <tile id="102" type="ground::dirt"/>
 <tile id="104" type="ground::sand"/>
 <tile id="106" type="ground::path"/>
 <tile id="108" type="water">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="-0.1"/>
   <property name="is_water" type="bool" value="true"/>
  </properties>
 </tile>
 <tile id="110" type="ground::clay"/>
 <tile id="140" type="wall">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="1"/>
  </properties>
 </tile>
 <tile id="141" type="wall">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="1"/>
  </properties>
 </tile>
 <tile id="142" type="wall">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="1"/>
  </properties>
 </tile>
 <tile id="160" type="rock">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="0.5"/>
  </properties>
 </tile>
 <tile id="161" type="rock">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="0.5"/>
  </properties>
 </tile>
 <tile id="162" type="rock"/>
 <tile id="163" type="rock">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="0.5"/>
  </properties>
 </tile>
 <tile id="164" type="rock">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="0.7"/>
  </properties>
 </tile>
 <tile id="165" type="rock">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="0.5"/>
  </properties>
 </tile>
 <tile id="180">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="1"/>
  </properties>
 </tile>
 <tile id="183">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="0.5"/>
  </properties>
 </tile>
</tileset>
