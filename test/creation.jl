using LightGraphs

@testset "Graph creation" begin
    g = StorageGraph()
    @test get_prop(g) == 1
    @test nextid(g, (A=1,)=>(D=0.4,)) == 1
    add_nodes!(g, (A=1,)=>(D=0.4,)=>(B=0.5,))
    @test length(g.data) == length(g.index)
    @test nv(g) == 3
    @test ne(g) == 2
    @test g.data == Dict(1=>(D=0.4,), 2=>(B=0.5,), 3=>(A=1,))
    @test g.index == Dict((D=0.4,)=>1, (B=0.5,)=>2, (A=1,)=>3)
    @test g.paths == Dict(Edge(1,2)=>Set(1), Edge(3,1)=>Set(1))
    @test get_prop(g) == 2
    dep1 = (A=1,)=>(D=0.4,)=>(B=0.5,)
    dep2 = (A=1,)=>(D=0.4,)=>(B=0.6,)
    dep3 = (A=1,)=>(D=0.5,)=>(B=0.5,)
    dep4 = (A=2,)=>(D=0.4,)
    @test nextid(g, dep1) == 1
    @test nextid(g, dep2) == 2
    @test nextid(g, dep3) == 2
    @test nextid(g, dep3) == 2
end

@testset "Adding data proggresively" begin
    g = StorageGraph()

    @testset "add_nodes!" begin
        add_nodes!(g, (A=1,)=>(B=0.4,))
        @test nv(g) == 2
        @test ne(g) == 1
    end

    val1 = (q₀=[[0,1],[0,2],[0,3]], q₂=[[2,1],[2,2],[2,3]])
    @testset "add_bulk!" begin
        add_bulk!(g, (A=1,)=>(B=0.4,), val1)
        @test nv(g) == 5
        @test ne(g) == 4
        @test get_prop(g, 1) == (A=1,)
        @test get_prop(g, 2) == (B=0.4,)
        @test get_prop(g, 3) == (q₀=[0,1],q₂=[2,1])
        @test get_prop(g, 4) == (q₀=[0,2],q₂=[2,2])
        @test get_prop(g, 5) == (q₀=[0,3],q₂=[2,3])
        @test get_prop(g, 1, 2) == Set([1,2,3])
        @test get_prop(g, 2, 3) == Set(1)
        @test get_prop(g, 2, 4) == Set(2)
        @test get_prop(g, 2, 5) == Set(3)

        @test nextid(g, (A=1,)=>(B=0.5,)=>(x=1,)) == 4
        add_bulk!(g, (A=1,)=>(B=0.5,), (q₀=[[0,-1],[0,-2]], q₂=[[2,-1],[2,-2]]))
        @test nv(g) == 8
        @test ne(g) == 7
        @test get_prop(g, 6) == (B=0.5,)
        @test get_prop(g, 7) == (q₀=[0,-1],q₂=[2,-1])
        @test get_prop(g, 8) == (q₀=[0,-2],q₂=[2,-2])
        @test get_prop(g, 1, 6) == Set([4,5])
        @test get_prop(g, 6, 7) == Set(4)
        @test get_prop(g, 6, 8) == Set(5)
    end

    l = (l=0.1:0.1:0.3,)
    @testset "add_derived_values!" begin
        add_derived_values!(g, ((A=1,), (B=0.4,)), val1, l, (t=1,))
        @test nv(g) == 12
        @test ne(g) == 13
        @test get_prop(g, 1, 2) == Set([1,2,3])
        @test get_prop(g, 9) == (t=1,)
        @test get_prop(g, 2, 3) == get_prop(g, 3, 9) == get_prop(g, 9, 10) == Set(1)
        @test get_prop(g, 2, 4) == get_prop(g, 4, 9) == get_prop(g, 9, 11) == Set(2)
        @test get_prop(g, 2, 5) == get_prop(g, 5, 9) == get_prop(g, 9, 12) == Set(3)

        g = StorageGraph()
        dep = ((a=1,),(b=1,),(c=1,))
        add_bulk!(g, foldr(=>,dep), (d=[1,2],))
        @test get_prop(g, 1) == (b=1,)
        @test get_prop(g, 2) == (c=1,)
        @test get_prop(g, 3) == (a=1,)
        @test get_prop(g, 4) == (d=1,)
        @test get_prop(g, 5) == (d=2,)
        @test get_prop(g, 3, 1) == Set([1,2])
        @test get_prop(g, 1, 2) == Set([1,2])
        @test get_prop(g, 2, 4) == Set(1)
        @test get_prop(g, 2, 5) == Set(2)

        add_nodes!(g, (a=1,)=>(b=2,)=>(c=1,)=>(d=2,))
        @test get_prop(g, 6) == (b=2,)
        @test get_prop(g, 3, 1) == Set([1,2])
        @test get_prop(g, 3, 6) == Set(3)
        @test get_prop(g, 6, 2) == Set(3)
        @test get_prop(g, 2, 5) == Set([2, 3])

        add_nodes!(g, (a=1,)=>(b=1,)=>(c=1,)=>(d=3,))
        @test get_prop(g, 3, 1) == get_prop(g, 1, 2) == Set([1,2,4])
        @test get_prop(g, 7) == (d=3,)
        @test get_prop(g, 2, 7) == Set(4)

        add_nodes!(g, (a=1,)=>(b=1,)=>(c=2,))
        @test get_prop(g, 8) == (c=2,)
        @test get_prop(g, 3, 1) == Set([1,2,4,5])
        @test get_prop(g, 1, 8) == Set(5)

        add_derived_values!(g, dep, (d=[1,2],), (f=[1,2],), (e=1,))
        @test nv(g) == 11
        @test ne(g) == 12
        @test get_prop(g, 3, 1) == Set([1,2,4,5])
        @test get_prop(g, 1, 2) == Set([1,2,4])
        @test get_prop(g, 2, 4) == Set(1)
        @test get_prop(g, 9) == (e=1,)
        @test get_prop(g, 10) == (f=1,)
        @test get_prop(g, 11) == (f=2,)
        @test get_prop(g, 4, 9) == get_prop(g, 9, 10) == Set(1)
        @test get_prop(g, 2, 5) == Set([2, 3])
        @test get_prop(g, 5, 9) == get_prop(g, 9, 11) == Set(2)
    end
end

@testset "Adding data from scratch" begin
    g = StorageGraph()

    @testset "add_nodes!" begin
        add_nodes!(g, (A=1,)=>(B=0.4,))
        @test nv(g) == 2
        @test ne(g) == 1
    end

    g = StorageGraph()

    @testset "add_bulk!" begin
        dep = (q₀=[[0,1],[0,2],[0,3]], q₂=[[2,1],[2,2],[2,3]])
        add_bulk!(g, (A=1,)=>(B=0.4,), dep)
        @test nv(g) == 5
        @test ne(g) == 4
    end

    g = StorageGraph()

    @testset "add_derived_values!" begin
        dep = (q₀=[[0,1],[0,2]], q₂=[[2,1],[2,2]])
        l1 = (l=[0.1,0.2],)
        add_derived_values!(g, ((A=1,), (B=0.4,)), dep, l1, (t=1,))
        @test nv(g) == 7
        @test ne(g) == 7
    end
end