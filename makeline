# Place your Python script code here ...
from pyjdg import *
import ctypes
def get_selected_node(dlg):
    global array_node,array_face
    array_node = JPT.GetSelectedNodes()
    array_face = JPT.GetSelectedFaces()
    # print(len(array_face))
    # print(len(array_node))
    if len(array_face)==0:
        return 1
    else:
        return 0
def draw_line_vjp(dlg):
    start_node = array_node[0].id
    dummy_array = JPT.Exec(f'AssociatedPick([10:{start_node}], "Face", "UNKNOWN")')
    # print(f'the test value is :{dummy_array}')
    # for n in range(4):
    #     dummy_array = JPT.Exec(f'AssociatedPick({dummy_array}, "Edge", "UNKNOWN")')
    #     dummy_array = JPT.Exec(f'AssociatedPick({dummy_array}, "Face", "UNKNOWN")')
    test = JPT.Exec(f'Geom_ShowAdjacent(0, 0, 4, 0, {dummy_array}, [])')
    
    print(f'the test face is{test}')
    items = test.strip("[]").split(", ")

    extracted_faces = [int(item.split(":")[1]) for item in items] 
    valid_faces = [Face(face_id) for face_id in extracted_faces]
    created_edges = Geometry.Edge.Line(
        dllPoints=[
            [array_node[0].pos.x, array_node[0].pos.y, array_node[0].pos.z],
            [array_node[1].pos.x, array_node[1].pos.y, array_node[1].pos.z]
        ],
        crlFaces= valid_faces
    )
    JPT.Debugger(created_edges)

# Simulate Space Key
def show_selector():
    ctypes.windll.user32.keybd_event(0x20, 0, 0, 0)  #Simulate key press
    ctypes.windll.user32.keybd_event(0x20, 0, 2, 0)  #Simulate key release

def merge_face(dlg):
    if len(array_face) < 2:
        print("At least two faces must be selected for merging.")
        return
 
    faces_to_merge = [Face(face.id) for face in array_face]
    merged_faces = Geometry.MergeEntities.Faces(crlFaces=faces_to_merge)
    JPT.Debugger(merged_faces)
 
def draw_line(dlg):
    
    try:
        # print(array_face[0].id)
        # print(array_face[1].id)
        # print(array_face[2].id)
        valid_faces = [Face(face.id) for face in array_face if face.id != 0]
        created_edges = Geometry.Edge.Line(
            dllPoints=[
                [array_node[0].pos.x, array_node[0].pos.y, array_node[0].pos.z],
                [array_node[1].pos.x, array_node[1].pos.y, array_node[1].pos.z]
            ],
            #crlFaces=[
                #Face(array_face[0].id,array_face[1].id,array_face[2].id)
            #]
            crlFaces= valid_faces
        )
        JPT.Debugger(created_edges)
    except IndexError as e:
        print(f"index error {e}")
    except Exception as e:
        print(f"except error {e}")

    
def on_button_OK_clicked(dlg):
    #print("button clickegd")
    status = get_selected_node(dlg)
    if status == 1:
        draw_line_vjp(dlg)
        return
    if dlg.isbutton_checked(name="merge") and dlg.isbutton_checked(name="draw"):
        merge_face(dlg)
        draw_line(dlg)
        return
    elif dlg.isbutton_checked(name="draw"):
        draw_line(dlg)
        return
    elif dlg.isbutton_checked(name="merge"):
        merge_face(dlg)
        return
    # merge_face(dlg)
def main():
    dlg=JDGCreator(title="Dialog")
    dlg.add_face_selector()
    dlg.add_node_selector()
    
    dlg.add_groupbox(name="GroupBox2",text="Merge + Draw Line",layout="Window")
    dlg.add_layout(name="Layout5",margin=[0,10,0,0],orientation=orientation.horizontal,layout="GroupBox2")
    dlg.add_checkbox(name="merge",text="Merge Face",checked=True,lefttext=True,layout="GroupBox2")
    dlg.add_checkbox(name="draw",text="Draw Line   ",checked=True,lefttext=True,layout="GroupBox2")
    dlg.add_layout(name="Layout6",margin=[0,0,0,10],orientation=orientation.horizontal,layout="GroupBox2")
    dlg.add_richeditbox(name="RichEditBox5",text="50k nha anh =))))))",width=200,height=50,layout="GroupBox2")
    
    dlg.on_dlg_apply(callfunc=on_button_OK_clicked)
    dlg.on_dlg_ok(callfunc=on_button_OK_clicked)
    show_selector()
    dlg.generate_window()
if __name__=='__main__':
    main()

# Place your Python script code here ...
