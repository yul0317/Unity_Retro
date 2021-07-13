Shader "jong/Cloaking"
{
    Properties
    {
        _MainTex("Albeo Texture",2D) = "white"{} //기본텍스쳐 설정
        _NormalMap("Normal Map",2D) = "bump"{}  //주변의 빛을 굴절 시키는 효과
        _Opacity("Opacity",Range(0,1))=0.1    //투명도. 뒤에 있는 배경과 얼마나 섞일지 0으로 하면 투명, 1로하면 안섞임
        _DeformIntensity("Deform by Normal Intensity",Range(0,3))=1  //빛의 굴절효과를 얼마나 강하게 할지. 값을 높이면 빛이 산란이 되어서 보이지 않는 외곽선이 존재한다고 느낌.
        _RimPow("Rim Power",int) = 3 //림라이팅. 림효과.. 외곽선이 푸르딩딩하게 빛나게? 정확하게 몇승값인데. 1보다 작은값들은 제곱할수록 값이 작아짐. 그래서 림파워를 높이게 되면 얇아짐.
        _RimColor("Rim Color",Color) = (0,1,1,1)
    }
    SubShader
    {
        Tags {"Queue" = "Transparent" "RenderType"="Opaque" }
        zwrite off  //카메라에 zoff값을 덮어쓰지 않게 사용

        //grabpass 를 사용하면 . 밑에 있는거를 그리기 전에 화면을 가지고옴. 
        GrabPass{}
        //안에 아무것도 작성안하면 밑에 sampler2D의 예약어인 _GrabTexture로 옴  
        //작성하면 {"myGrab"} -> myGrab

        CGPROGRAM
        //#pragma surface surf Standard fullforwardshadows
        //내가 사용하고자 하는 라이팅 모델이 들어가게 됨. 
        //클로킹을 사용하면 그림자 받아야하나. 뭐 등등 여러가지를 생각해야하는데 간단하게
        //밝으면 밝고 주변이 어두우면 어둡고. 
        //noambient < 앰비언트의 영향을 받지 않도록
        //novertexlights noforwarded    포워드 라이팅에서 포워드 프로브의 영향을 안받게 됨.
        #pragma surface surf CloakingLight noambient novertexlights noforwardadd
        #pragma target 3.0

        sampler2D _GrabTexture;
        sampler2D _MainTex;
        sampler2D _NormalMap;

        float _DeformIntensity;
        float _Opacity;
        float _RimPow;
        float3 _RimColor;

        //surface shader에 입력으로 들어갈 데이터
        struct Input
        {
            float4 screenPos;   //grabpass로 잡은 텍스쳐를 샘플링 할때 사용할것 
            //해당 버텍스가 어떠한 스크린상의 좌표를 가지는지 알려주고, 그럼 그 스크린 좌표를 통해서 대상이 배경의 어느 위치에 있는지 알수 있음.

            float2 uv_MainTex;
            float2 uv_NormalMap;
            float3 viewDir; //뷰어의 방향(카메라의 방향)

        };

        void surf (Input IN, inout SurfaceOutput o)
        {
            o.Normal = UnpackNormal(tex2D(_NormalMap, IN.uv_NormalMap));
            //해당 픽셀의 노말을 결정해야함. suface 장점이 노말값을 할당해주면 노말효과가 적용됨
            //노말맵으로 부터 노말데이터를 가지고 와서 할당해주고
            float4 color = tex2D(_MainTex, IN.uv_MainTex);
            //최종 출력할 컬러를 지정 , 메인텍스쳐에서 현재 버텍스에 대응되는 uv좌표로 부터 컬러를 샘플링해서 들고와서 할당해주고

            float2 uv_screen = IN.screenPos.xy / IN.screenPos.w;
            //현재 버텍스가 스크린텍스쳐에 어떤 uv좌표에 대응이 되는지 가지고 올꺼임. 호모지니어스 좌표계에서 xyzw 에서 w가 1인 좌표로 변경해줘야함.

            fixed3 mappingScreenColor = tex2D(_GrabTexture,uv_screen + o.Normal.xy * _DeformIntensity);
            //거기에 대응되는 컬러를 가지고 와야함.
            //샘플링을 시도할때 일부로 어긋난값을 쓸 수 있도록. 더해줌. 거기에 곱하는건 노말에 의한 deform으로 조절하기 위해서 

            float rimBrightness = 1 - saturate(dot(IN.viewDir, o.Normal));
            //림라이팅을 적용하기 위해서.
            //saturate ()   <<0~1사이 값으로 잘림.
            //보는사람의 방향과 해당방향의 표면이 엇나가면 0에 가까워짐 
            //근데 1- 라서 반대로 rimBrightness값은 커짐 
            //물체의 요약성이 밝아지고 아닌부분은 0에 가까워짐

            rimBrightness = pow(rimBrightness, _RimPow);
            //0~1값을 가지는데 제곱을 하면 작아지기에 림파워를 통해 뭐 조작가능

            o.Emission = mappingScreenColor * (1 - _Opacity) + _RimColor * rimBrightness;
            //Emission << 스스로 빛을 냄 주변에 광원이 없어도 뒷배경이 보임..?
            
            o.Albedo = color.rgb;
        }

        fixed4 LightingCloakingLight(SurfaceOutput s, float3 lightDir, float atten){
            //surfaceshader를 통해 처리가 끝난 이미 다 그려진 픽셀(라이팅제외),라이팅이 오는 방향, 명도(빛의 색)
            return fixed4(s.Albedo*_Opacity * _LightColor0, 1);
            // s.Albedo * _Opacity << 불투명도를 곱함. 값이 작으면 투명해지니 안보임
            // _LightColor0 << 예약어. 씬에서 제일 먼저 들어오는 빛? 을 가져옴

        }

        ENDCG
    }
    FallBack "Diffuse"
}
